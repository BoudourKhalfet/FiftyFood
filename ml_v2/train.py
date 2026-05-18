"""
Train, evaluate, and persist the CatBoost offer expiration risk model.

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

# ── Paths ─────────────────────────────────────────────────────────────────────
MODEL_DIR = "models"
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

    sep = "─" * 65
    print(f"\n{sep}")
    print("  Walk-Forward Cross-Validation")
    print(sep)

    results: list[dict] = []
    for fold in range(n_folds):
        train_df = df.iloc[: chunk * (fold + 1)]
        val_df = df.iloc[chunk * (fold + 1) : chunk * (fold + 2)]

        X_tr, y_tr, _, cat_idx = build_features(train_df)
        X_val, y_val, _, _ = build_features(val_df)

        neg, pos = (y_tr == 0).sum(), (y_tr == 1).sum()
        spw = float(neg / max(pos, 1))

        # Fixed 300 iterations for CV — no early stopping to avoid eval-set bias
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
        print(
            f"  Fold {fold + 1}  train={len(train_df):4d}  val={len(val_df):3d}  "
            f"AUC={row['auc']:.4f}  F1={row['f1']:.4f}  "
            f"Recall={row['recall']:.4f}  Prec={row['precision']:.4f}"
        )

    cv_df = pd.DataFrame(results)
    print(sep)
    print(
        f"  Mean ± Std  "
        f"AUC  = {cv_df['auc'].mean():.4f} ± {cv_df['auc'].std():.4f}  "
        f"F1   = {cv_df['f1'].mean():.4f} ± {cv_df['f1'].std():.4f}  "
        f"Rec  = {cv_df['recall'].mean():.4f} ± {cv_df['recall'].std():.4f}"
    )
    print(sep)
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
    print(f"  📊  {path}")


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
    print(f"  📊  {path}")


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
    print(f"  📊  {path}")


# ─────────────────────────────────────────────────────────────────────────────
def train() -> tuple[CatBoostClassifier, IsotonicRegression]:
    sep = "─" * 65

    # ── 1. Load & sort ────────────────────────────────────────────────────────
    print(f"\n{sep}")
    print("  Loading offer_history.csv …")
    df = pd.read_csv("offer_history.csv", parse_dates=["created_at"])
    df = df.sort_values("created_at").reset_index(drop=True)
    print(f"  {len(df)} offers  |  expiration rate: {df['expired'].mean():.1%}")
    print(sep)

    # ── 2. Temporal splits — no shuffle, ever ─────────────────────────────────
    n = len(df)
    n_train = int(n * 0.75)  # 900 — training pool
    n_calib = int(n * 0.10)  # 120 — isotonic calibration
    # remaining  15%  (180) — held-out test set, touched only for final reporting
    n_es = int(n_train * 0.20)  # larger ES val set → more reliable stopping signal

    train_df = df.iloc[: n_train - n_es]
    es_df = df.iloc[n_train - n_es : n_train]
    calib_df = df.iloc[n_train : n_train + n_calib]  # 120 samples
    test_df = df.iloc[n_train + n_calib :]  # 180 samples

    print(
        f"  Train: {len(train_df)}  |  EarlyStopping val: {len(es_df)}  "
        f"|  Calibration: {len(calib_df)}  |  Test: {len(test_df)}"
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
    print(f"\n{sep}")
    print(f"  Training CatBoost  (scale_pos_weight={spw:.2f})")
    print(sep)

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
    print(f"\n  Best iteration: {best_iter}")

    # ── 6. Isotonic calibration ───────────────────────────────────────────────
    # Fit on calib_df (temporally after training, before test — no leakage).
    proba_calib_raw = model.predict_proba(X_cb)[:, 1]
    calibrator = IsotonicRegression(out_of_bounds="clip")
    calibrator.fit(proba_calib_raw, y_cb)
    ece_pre_calib = _ece(y_cb, proba_calib_raw)
    ece_post_calib = _ece(y_cb, calibrator.predict(proba_calib_raw))
    print(f"  Calibration  ECE before={ece_pre_calib:.4f}  after={ece_post_calib:.4f}")

    # ── 7. Test-set evaluation ────────────────────────────────────────────────
    proba_raw = model.predict_proba(X_te)[:, 1]
    proba_cal = np.clip(calibrator.predict(proba_raw), 0.0, 1.0)
    pred = (proba_cal >= 0.50).astype(int)

    auc = roc_auc_score(y_te, proba_cal)
    ece = _ece(y_te, proba_cal)

    print(f"\n{sep}")
    print(f"  Final Test-Set Results  (n={len(test_df)})")
    print(sep)
    print(f"  ROC-AUC : {auc:.4f}")
    print(f"  ECE     : {ece:.4f}  (↓ lower = better calibration)")
    print(
        f"\n{classification_report(y_te, pred, target_names=['SOLD_OUT', 'EXPIRED'])}"
    )

    # ── 8. Plots ──────────────────────────────────────────────────────────────
    print("  Saving diagnostic plots …")
    _plot_feature_importance(model, feat)
    _plot_calibration(y_te, proba_raw, proba_cal)
    _plot_roc(y_te, proba_cal)

    # ── 9. Persist ────────────────────────────────────────────────────────────
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
        },
        ARTIF_PATH,
    )

    print(f"\n  ✅  Model     →  {MODEL_PATH}")
    print(f"  ✅  Artifacts →  {ARTIF_PATH}")
    print(sep)

    return model, calibrator


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    train()
