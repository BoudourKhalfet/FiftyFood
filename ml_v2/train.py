"""
Train, evaluate, and persist the CatBoost offer expiration risk model.

Improvements over v1:
  - Calibration set increased from 10% to 15% → more stable isotonic regression
  - Auto-switch to Platt scaling (LogisticRegression) when calib set < 200 samples
    Isotonic regression overfits on small datasets; Platt scaling is safer there.
  - _PlattCalibrator moved to module level → joblib serialization safe
  - _MIN_GROUP_SAMPLES moved to module level constant (20) → visible and tunable
  - Data-driven optimal description_length and time_to_pickup per establishment type

Pipeline
--------
1. Load offer_history.csv and sort chronologically (no shuffle — ever).
2. Walk-forward CV on the training portion → stability report.
3. Train final CatBoost with early stopping on a held-out validation slice.
4. Calibrate predicted probabilities with isotonic regression.
5. Evaluate on untouched test set: AUC, F1, Recall, ECE.
6. Save model + artifacts.

Run:
    python train.py   (requires offer_history.csv from generator.py)
"""

import logging
import os
import warnings

import joblib
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier, Pool
from features import CATEGORICAL_FEATURES, build_features
from sklearn.calibration import calibration_curve
from sklearn.isotonic import IsotonicRegression
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    classification_report,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)

matplotlib.use("Agg")  # headless — safe in all environments
warnings.filterwarnings("ignore")

logger = logging.getLogger(__name__)

# ── Paths ─────────────────────────────────────────────────────────────────────
MODEL_DIR = "models"


# ── Lookup table config ───────────────────────────────────────────────────────
# Minimum number of offers a (establishment_type, feature_value) group must have
# before its sell rate is considered reliable enough to use in tip tables.
# Groups below this threshold fall back to the hardcoded constants in predictor.py.
# 20 is a reasonable floor: enough to suppress pure noise while keeping coverage
# on a dataset of ~1400 training offers across 6 establishment types.
_MIN_GROUP_SAMPLES: int = 20

# ── Calibration threshold ─────────────────────────────────────────────────────
# Minimum calibration set size for IsotonicRegression to be safe.
# Below this, _PlattCalibrator (logistic regression) is used instead.
_ISOTONIC_MIN_SAMPLES: int = 200

MODEL_PATH = os.path.join(MODEL_DIR, "model.cbm")
ARTIF_PATH = os.path.join(MODEL_DIR, "artifacts.pkl")

# ── CatBoost base hyperparameters ─────────────────────────────────────────────
# Anti-overfitting stack: shallow depth + strong L2 + Bernoulli subsampling.
# learning_rate 0.05 is conservative; early stopping finds the right iteration count.
BASE_PARAMS: dict = dict(
    learning_rate=0.05,
    depth=3,  # 8 leaves max — hard cap on memorisation
    l2_leaf_reg=20.0,  # aggressive weight decay
    min_data_in_leaf=50,  # each leaf needs at least 50 samples
    random_strength=2.0,  # high split randomisation
    bootstrap_type="Bernoulli",  # classical row subsampling
    subsample=0.70,  # only 70 % of rows per tree
    border_count=32,  # fewer candidate splits per feature
    loss_function="Logloss",
    eval_metric="AUC",
    random_seed=42,
    verbose=False,
)


# ── Platt calibrator — module-level so joblib can serialize/deserialize ───────
# Must NOT be defined inside train() — pickle stores the class path as
# train._PlattCalibrator and needs to find it at module scope on load.
class _PlattCalibrator:
    """
    Thin wrapper around LogisticRegression that exposes the same
    .predict() interface as IsotonicRegression.

    Used when the calibration set is too small for isotonic regression
    (< 200 samples). Platt scaling is parametric and much less prone
    to overfitting on small datasets.
    """

    def __init__(self, lr: LogisticRegression) -> None:
        self._lr = lr

    def predict(self, X: np.ndarray) -> np.ndarray:
        return self._lr.predict_proba(np.asarray(X).reshape(-1, 1))[:, 1]


# ─────────────────────────────────────────────────────────────────────────────
def _pool(X: np.ndarray, y: np.ndarray | None, cat_idx: list[int]) -> Pool:
    return Pool(X, label=y, cat_features=cat_idx)


def _ece(y_true: np.ndarray, proba: np.ndarray, n_bins: int = 10) -> float:
    """Expected Calibration Error — measures reliability of predicted probabilities."""
    bins = np.linspace(0.0, 1.0, n_bins + 1)
    ece = 0.0
    n = len(y_true)
    for lo, hi in zip(bins[:-1], bins[1:]):
        mask = (proba >= lo) & (proba < hi)
        if mask.sum() == 0:
            continue
        ece += mask.sum() / n * abs(y_true[mask].mean() - proba[mask].mean())
    return float(ece)


# ─────────────────────────────────────────────────────────────────────────────
def walk_forward_cv(df: pd.DataFrame, n_folds: int = 3) -> pd.DataFrame:
    """
    Temporal walk-forward cross-validation.

    Training window expands fold by fold; validation window is always the
    immediately following chunk. This mirrors real deployment: the model
    never sees future data during training.

    CV uses a fixed iteration count (no early stopping) to keep folds
    comparable and avoid contaminating the validation metric with stopping info.
    """
    n = len(df)
    chunk = n // (n_folds + 1)  # each fold adds one chunk to training, tests next one

    logger.info("Walk-Forward Cross-Validation")

    results: list[dict] = []
    for fold in range(n_folds):
        train_df = df.iloc[: chunk * (fold + 1)]
        val_df = df.iloc[chunk * (fold + 1) : chunk * (fold + 2)]

        X_tr, y_tr, _, cat_idx = build_features(train_df)
        X_val, y_val, _, _ = build_features(val_df)

        neg, pos = (y_tr == 0).sum(), (y_tr == 1).sum()
        spw = float(neg / max(pos, 1))

        # Fixed 200 iterations for CV — no early stopping to avoid eval-set bias
        cv_params = {
            **BASE_PARAMS,
            "iterations": 200,
            "scale_pos_weight": spw,
        }
        model = CatBoostClassifier(**cv_params)
        model.fit(_pool(X_tr, y_tr, cat_idx), verbose=False)

        proba = model.predict_proba(X_val)[:, 1]
        pred = (proba >= 0.50).astype(int)

        row = dict(
            fold=fold + 1,
            train_n=len(train_df),
            val_n=len(val_df),
            auc=round(roc_auc_score(y_val, proba), 4),
            f1=round(f1_score(y_val, pred, zero_division=0), 4),
            recall=round(recall_score(y_val, pred, zero_division=0), 4),
            precision=round(precision_score(y_val, pred, zero_division=0), 4),
        )
        results.append(row)
        logger.info(
            "Fold %d  train=%4d  val=%3d  AUC=%.4f  F1=%.4f  Recall=%.4f  Prec=%.4f",
            fold + 1,
            len(train_df),
            len(val_df),
            row["auc"],
            row["f1"],
            row["recall"],
            row["precision"],
        )

    cv_df = pd.DataFrame(results)
    logger.info(
        "CV Mean±Std  AUC=%.4f±%.4f  F1=%.4f±%.4f  Rec=%.4f±%.4f",
        cv_df["auc"].mean(),
        cv_df["auc"].std(),
        cv_df["f1"].mean(),
        cv_df["f1"].std(),
        cv_df["recall"].mean(),
        cv_df["recall"].std(),
    )
    return cv_df


# ─────────────────────────────────────────────────────────────────────────────
def _plot_feature_importance(
    model: CatBoostClassifier, feature_names: list[str]
) -> None:
    importances = model.get_feature_importance()
    order = np.argsort(importances)
    fig, ax = plt.subplots(figsize=(9, 6))
    ax.barh(
        [feature_names[i] for i in order],
        importances[order],
        color="steelblue",
        edgecolor="white",
    )
    ax.set_xlabel("CatBoost Feature Importance (averaged over trees)")
    ax.set_title("Feature Importance — Offer Expiration Risk Model")
    fig.tight_layout()
    path = os.path.join(MODEL_DIR, "feature_importance.png")
    fig.savefig(path, dpi=130)
    plt.close(fig)
    logger.info("Saved %s", path)


def _plot_calibration(
    y_true: np.ndarray,
    proba_raw: np.ndarray,
    proba_cal: np.ndarray,
) -> None:
    fig, ax = plt.subplots(figsize=(7, 5))
    for label, proba, color, ls in [
        ("Before calibration", proba_raw, "steelblue", "--"),
        ("After calibration", proba_cal, "tomato", "-"),
    ]:
        frac_pos, mean_pred = calibration_curve(y_true, proba, n_bins=10)
        ax.plot(mean_pred, frac_pos, marker="o", color=color, ls=ls, label=label)
    ax.plot([0, 1], [0, 1], "k:", lw=1, label="Perfect calibration")
    ax.set_xlabel("Mean predicted probability")
    ax.set_ylabel("Fraction of positives (actual)")
    ax.set_title("Calibration Curve — Test Set")
    ax.legend()
    fig.tight_layout()
    path = os.path.join(MODEL_DIR, "calibration_curve.png")
    fig.savefig(path, dpi=130)
    plt.close(fig)
    logger.info("Saved %s", path)


def _plot_roc(y_true: np.ndarray, proba: np.ndarray) -> None:
    fpr, tpr, _ = roc_curve(y_true, proba)
    auc = roc_auc_score(y_true, proba)
    fig, ax = plt.subplots(figsize=(6, 5))
    ax.plot(fpr, tpr, color="tomato", lw=2, label=f"AUC = {auc:.4f}")
    ax.plot([0, 1], [0, 1], "k:", lw=1)
    ax.set_xlabel("False Positive Rate")
    ax.set_ylabel("True Positive Rate")
    ax.set_title("ROC Curve — Test Set (calibrated)")
    ax.legend()
    fig.tight_layout()
    path = os.path.join(MODEL_DIR, "roc_curve.png")
    fig.savefig(path, dpi=130)
    plt.close(fig)
    logger.info("Saved %s", path)


# ─────────────────────────────────────────────────────────────────────────────
def train() -> tuple[CatBoostClassifier, IsotonicRegression | _PlattCalibrator]:
    sep = "─" * 65

    # ── 1. Load & sort ────────────────────────────────────────────────────────
    logger.info("Loading offer_history.csv …")
    df = pd.read_csv("offer_history.csv", parse_dates=["created_at"])
    df = df.sort_values("created_at").reset_index(drop=True)
    logger.info(
        "%d offers  |  expiration rate: %.1f%%", len(df), df["expired"].mean() * 100
    )

    # ── 2. Temporal splits — no shuffle, ever ─────────────────────────────────
    n = len(df)
    n_train = int(n * 0.70)  # training pool (was 0.75 — freed 5% for calibration)
    n_calib = int(n * 0.15)  # 15% calibration — was 10%, isotonic needs more samples
    # remaining 15% — held-out test set, touched only for final reporting
    n_es = int(n_train * 0.20)  # larger ES val set → more reliable stopping signal

    train_df = df.iloc[: n_train - n_es]
    es_df = df.iloc[n_train - n_es : n_train]
    calib_df = df.iloc[n_train : n_train + n_calib]
    test_df = df.iloc[n_train + n_calib :]

    logger.info(
        "Splits — Train: %d  EarlyStopping: %d  Calibration: %d  Test: %d",
        len(train_df),
        len(es_df),
        len(calib_df),
        len(test_df),
    )

    # ── 3. Walk-forward CV (stability check on training pool) ─────────────────
    walk_forward_cv(df.iloc[:n_train], n_folds=3)

    # ── 4. Build feature matrices ─────────────────────────────────────────────
    X_tr, y_tr, feat, cat_idx = build_features(train_df)
    X_es, y_es, _, _ = build_features(es_df)
    X_cb, y_cb, _, _ = build_features(calib_df)
    X_te, y_te, _, _ = build_features(test_df)

    # Class weighting — ensures the model doesn't under-predict the minority class
    neg, pos = (y_tr == 0).sum(), (y_tr == 1).sum()
    spw = float(neg / max(pos, 1))

    # ── 5. Train final model with early stopping ──────────────────────────────
    logger.info("Training CatBoost  (scale_pos_weight=%.2f)", spw)

    final_params = {
        **BASE_PARAMS,
        "iterations": 300,  # hard cap — prevents cumulative over-capacity
        "early_stopping_rounds": 30,  # stop fast if ES val plateaus
        "scale_pos_weight": spw,
        "verbose": 50,
    }
    model = CatBoostClassifier(**final_params)
    model.fit(
        _pool(X_tr, y_tr, cat_idx),
        eval_set=_pool(X_es, y_es, cat_idx),
    )
    best_iter = model.get_best_iteration()
    logger.info("Best iteration: %d", best_iter)

    # ── 6. Calibration ────────────────────────────────────────────────────────
    # Fit on calib_df (temporally after training, before test — no leakage).
    #
    # Strategy:
    #   ≥ 200 samples → IsotonicRegression  (non-parametric, more expressive)
    #   <  200 samples → Platt scaling via LogisticRegression  (parametric,
    #                    much less prone to overfitting on small sets)
    #
    # Both expose the same .predict() interface so the rest of the pipeline
    # is completely unaffected by which one is chosen.
    proba_calib_raw = model.predict_proba(X_cb)[:, 1]
    n_calib_actual = len(y_cb)

    if n_calib_actual >= _ISOTONIC_MIN_SAMPLES:
        calibrator = IsotonicRegression(out_of_bounds="clip")
        calibrator.fit(proba_calib_raw, y_cb)
        calib_method = "IsotonicRegression"
    else:
        # Platt scaling — logistic regression on raw scores.
        # _PlattCalibrator is defined at module level (not here) so that
        # joblib can serialize and deserialize it correctly in production.
        platt = LogisticRegression(C=1.0, solver="lbfgs", max_iter=200)
        platt.fit(proba_calib_raw.reshape(-1, 1), y_cb)
        calibrator = _PlattCalibrator(platt)  # type: ignore[assignment]
        calib_method = "PlattScaling"

    ece_pre_calib = _ece(y_cb, proba_calib_raw)
    ece_post_calib = _ece(y_cb, calibrator.predict(proba_calib_raw))
    logger.info(
        "Calibration [%s  n=%d]  ECE before=%.4f  after=%.4f",
        calib_method,
        n_calib_actual,
        ece_pre_calib,
        ece_post_calib,
    )

    # ── 7. Test-set evaluation ────────────────────────────────────────────────
    proba_raw = model.predict_proba(X_te)[:, 1]
    proba_cal = np.clip(calibrator.predict(proba_raw), 0.0, 1.0)
    pred = (proba_cal >= 0.50).astype(int)

    auc = roc_auc_score(y_te, proba_cal)
    ece = _ece(y_te, proba_cal)

    logger.info("Final Test-Set Results  (n=%d)", len(test_df))
    logger.info("ROC-AUC : %.4f", auc)
    logger.info("ECE     : %.4f  (lower = better calibration)", ece)
    logger.info(
        "\n%s",
        classification_report(y_te, pred, target_names=["SOLD_OUT", "EXPIRED"]),
    )

    # ── 8. Plots ──────────────────────────────────────────────────────────────
    logger.info("Saving diagnostic plots …")
    _plot_feature_importance(model, feat)
    _plot_calibration(y_te, proba_raw, proba_cal)
    _plot_roc(y_te, proba_cal)

    # ── 9. Data-driven lookup tables (training data only — no leakage) ────────
    # All four tables are computed exclusively from train_df.
    # Groups below _MIN_GROUP_SAMPLES are discarded — too few offers to be
    # statistically meaningful. The hardcoded constants in predictor.py remain
    # as fallbacks for any establishment type not covered here.

    # ── 9a. Best days per establishment type ──────────────────────────────────
    day_stats = (
        train_df.groupby(["establishment_type", "day_of_week"])
        .agg(sell_rate=("expired", lambda x: 1.0 - x.mean()), n=("expired", "count"))
        .reset_index()
    )
    day_stats = day_stats[day_stats["n"] >= _MIN_GROUP_SAMPLES]
    best_days_by_estab: dict[str, list[int]] = {}
    for estab, grp in day_stats.groupby("establishment_type"):
        ranked = grp.sort_values("sell_rate", ascending=False)["day_of_week"].tolist()
        best_days_by_estab[str(estab)] = [int(d) for d in ranked]

    # ── 9b. Best pickup hour per establishment type ───────────────────────────
    hour_stats = (
        train_df.groupby(["establishment_type", "pickup_hour"])
        .agg(sell_rate=("expired", lambda x: 1.0 - x.mean()), n=("expired", "count"))
        .reset_index()
    )
    hour_stats = hour_stats[hour_stats["n"] >= _MIN_GROUP_SAMPLES]
    # Store ALL hours ranked by sell_rate — predictor tests each via _cf_score.
    # Consistent with best_days_by_estab which also stores all ranked values.
    best_hours_by_estab: dict[str, list[int]] = {}
    for estab, grp in hour_stats.groupby("establishment_type"):
        ranked_hours = grp.sort_values("sell_rate", ascending=False)[
            "pickup_hour"
        ].tolist()
        best_hours_by_estab[str(estab)] = [int(h) for h in ranked_hours]

    # ── 9c. Optimal description length per establishment type ─────────────────
    # Strategy: median description_length of SOLD offers.
    # Rationale: sold offers represent the "good" distribution. The median is
    # robust to outliers (a few viral 300-char offers won't skew the suggestion).
    # The counterfactual is always validated through _cf_score before display.
    sold_df = train_df[train_df["expired"] == 0]
    desc_stats = (
        sold_df.groupby("establishment_type")
        .agg(
            optimal=("description_length", "median"), n=("description_length", "count")
        )
        .reset_index()
    )
    desc_stats = desc_stats[desc_stats["n"] >= _MIN_GROUP_SAMPLES]
    optimal_desc_by_estab: dict[str, int] = {
        str(row["establishment_type"]): int(round(row["optimal"]))
        for _, row in desc_stats.iterrows()
    }

    # ── 9d. Optimal time_to_pickup per establishment type ─────────────────────
    # Strategy: median time_to_pickup_hours of SOLD offers.
    # Only used as a tip when the current offer's lead time is meaningfully
    # shorter than this target — suggesting "post earlier next time".
    ttp_stats = (
        sold_df.groupby("establishment_type")
        .agg(
            optimal=("time_to_pickup_hours", "median"),
            n=("time_to_pickup_hours", "count"),
        )
        .reset_index()
    )
    ttp_stats = ttp_stats[ttp_stats["n"] >= _MIN_GROUP_SAMPLES]
    optimal_ttp_by_estab: dict[str, float] = {
        str(row["establishment_type"]): round(float(row["optimal"]), 1)
        for _, row in ttp_stats.iterrows()
    }

    # ── 9e. Quantity advice per (establishment_type × day_of_week) ─────────────
    # Strategy:
    #   - expired_rate  : fraction of offers that expired on this (estab, day) bucket.
    #   - suggested_qty : median quantity of SOLD offers on this day → the quantity
    #                     level at which offers actually cleared, not just got posted.
    #   - n_total       : sample count used as a confidence guard in the predictor.
    #
    # Rationale: restaurants sell surplus — they cannot choose WHICH day surplus
    # appears. What they CAN control is HOW MUCH they post. If a given day shows
    # a persistently high expiration rate, the quantity posted exceeds the typical
    # demand for that day.
    #
    # Used in predictor._qty_advice_for_day() to generate tips of the form:
    # "On Tuesdays you expire often — try [N] units instead of your current [M]."
    _all_day_agg = train_df.groupby(["establishment_type", "day_of_week"]).agg(
        expired_rate=("expired", "mean"),
        n_total=("expired", "count"),
    ).reset_index()

    _sold_day_agg = (
        train_df[train_df["expired"] == 0]
        .groupby(["establishment_type", "day_of_week"])
        .agg(suggested_qty=("quantity", "median"))
        .reset_index()
    )

    qty_day_stats = _all_day_agg.merge(
        _sold_day_agg, on=["establishment_type", "day_of_week"], how="left"
    )

    # Fallback for days with zero sold offers: use the overall median quantity
    # for that establishment type so we always have a plausible suggestion.
    _estab_median_qty = train_df.groupby("establishment_type")["quantity"].median()
    for _idx, _row in qty_day_stats.iterrows():
        if pd.isna(_row["suggested_qty"]):
            qty_day_stats.at[_idx, "suggested_qty"] = float(
                _estab_median_qty.get(_row["establishment_type"], 10.0)
            )

    qty_advice_by_day: dict[str, dict[int, dict]] = {}
    for _, _row in qty_day_stats.iterrows():
        _estab = str(_row["establishment_type"])
        _dow = int(_row["day_of_week"])
        qty_advice_by_day.setdefault(_estab, {})[_dow] = {
            "expired_rate": round(float(_row["expired_rate"]), 4),
            "suggested_qty": round(float(_row["suggested_qty"]), 1),
            "n_total": int(_row["n_total"]),
        }

    # ── 9e-bis. Per-restaurant per-day quantity advice ────────────────────────
    # More personalized than the estab_type bucket. Only meaningful for
    # restaurants with enough history on a given day (>= _MIN_GROUP_SAMPLES).
    # predictor._qty_advice_for_day() consults this first, falls back to
    # qty_advice_by_day when absent or n_total < threshold.
    _rest_estab_map = (
        train_df[["restaurant_id", "establishment_type"]]
        .drop_duplicates("restaurant_id")
        .set_index("restaurant_id")["establishment_type"]
    )

    _all_rest_day = train_df.groupby(["restaurant_id", "day_of_week"]).agg(
        expired_rate=("expired", "mean"),
        n_total=("expired", "count"),
    ).reset_index()

    _sold_rest_day = (
        train_df[train_df["expired"] == 0]
        .groupby(["restaurant_id", "day_of_week"])
        .agg(suggested_qty=("quantity", "median"))
        .reset_index()
    )

    qty_rest_day_stats = _all_rest_day.merge(
        _sold_rest_day, on=["restaurant_id", "day_of_week"], how="left"
    )

    # Fallback: days with no sold offers → estab-level median quantity
    for _idx, _row in qty_rest_day_stats.iterrows():
        if pd.isna(_row["suggested_qty"]):
            _estab = str(_rest_estab_map.get(_row["restaurant_id"], "UNKNOWN"))
            qty_rest_day_stats.at[_idx, "suggested_qty"] = float(
                _estab_median_qty.get(_estab, 10.0)
            )

    qty_advice_by_restaurant_day: dict[str, dict[int, dict]] = {}
    for _, _row in qty_rest_day_stats.iterrows():
        _rid = str(_row["restaurant_id"])
        _dow = int(_row["day_of_week"])
        qty_advice_by_restaurant_day.setdefault(_rid, {})[_dow] = {
            "expired_rate": round(float(_row["expired_rate"]), 4),
            "suggested_qty": round(float(_row["suggested_qty"]), 1),
            "n_total": int(_row["n_total"]),
        }

    _n_rest_actionable = sum(
        1
        for _rid_data in qty_advice_by_restaurant_day.values()
        for _stats in _rid_data.values()
        if _stats["expired_rate"] >= 0.40 and _stats["n_total"] >= _MIN_GROUP_SAMPLES
    )
    logger.info(
        "  qty_advice_by_restaurant_day: %d restaurant-day buckets  |  %d actionable (n >= %d)",
        sum(len(v) for v in qty_advice_by_restaurant_day.values()),
        _n_rest_actionable,
        _MIN_GROUP_SAMPLES,
    )

    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    logger.info("Data-driven lookup tables (from training data):")
    for estab in sorted(best_days_by_estab.keys()):
        days_str = ", ".join(day_names[d] for d in best_days_by_estab[estab])
        hours = best_hours_by_estab.get(estab, [])
        hour = hours[0] if hours else "?"
        desc = optimal_desc_by_estab.get(estab, "?")
        ttp = optimal_ttp_by_estab.get(estab, "?")
        logger.info(
            "  %-14s  days: %-20s  hour: %sh  desc: %s chars  ttp: %sh",
            estab,
            days_str,
            hour,
            desc,
            ttp,
        )

    logger.info(
        "  Quantity advice by day (expired_rate >= 40%%, n >= %d):", _MIN_GROUP_SAMPLES
    )
    for estab in sorted(qty_advice_by_day.keys()):
        for dow in sorted(qty_advice_by_day[estab].keys()):
            stats = qty_advice_by_day[estab][dow]
            if stats["expired_rate"] >= 0.40 and stats["n_total"] >= _MIN_GROUP_SAMPLES:
                logger.info(
                    "    %-14s  %s  expired=%.0f%%  suggest_qty=%.0f  n=%d",
                    estab,
                    day_names[dow],
                    stats["expired_rate"] * 100,
                    stats["suggested_qty"],
                    stats["n_total"],
                )

    # ── 10. Persist ───────────────────────────────────────────────────────────
    os.makedirs(MODEL_DIR, exist_ok=True)
    model.save_model(MODEL_PATH)
    joblib.dump(
        {
            "calibrator": calibrator,
            "feature_names": feat,
            "cat_indices": cat_idx,
            "cat_features": CATEGORICAL_FEATURES,
            "auc_test": round(auc, 4),
            "ece_test": round(ece, 4),
            "best_iteration": best_iter,
            "calib_method": calib_method,
            "calib_n_samples": n_calib_actual,
            "best_days_by_estab": best_days_by_estab,       # kept for backward compat
            "best_hours_by_estab": best_hours_by_estab,
            "optimal_desc_by_estab": optimal_desc_by_estab,
            "optimal_ttp_by_estab": optimal_ttp_by_estab,
            "qty_advice_by_day": qty_advice_by_day,                    # estab-type fallback
            "qty_advice_by_restaurant_day": qty_advice_by_restaurant_day,  # per-restaurant
        },
        ARTIF_PATH,
    )

    logger.info("Model     →  %s", MODEL_PATH)
    logger.info(
        "Artifacts →  %s  (calibration: %s  |  all lookup tables: data-driven)",
        ARTIF_PATH,
        calib_method,
    )

    return model, calibrator


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    train()
