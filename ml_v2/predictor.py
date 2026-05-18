"""
Inference engine for the offer expiration risk model.

Load once, call predict() on every hourly batch of active offers.
Returns a calibrated risk score, a risk level, and the top features
driving that risk — ready to feed a tip generator downstream.

Usage (standalone demo):
    python predictor.py   (requires trained model from train.py)
"""

import os

import joblib
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier, Pool
from features import build_features

MODEL_DIR = "models"
MODEL_PATH = os.path.join(MODEL_DIR, "model.cbm")
ARTIF_PATH = os.path.join(MODEL_DIR, "artifacts.pkl")

# ── Unlock gate — cold start guard ──────────────────────────────────────────
# Predictions are only meaningful once the restaurant has real history.
# Both conditions must be true before the predictor is called.
UNLOCK_MIN_OFFERS = 15  # minimum completed offers
UNLOCK_MIN_DAYS = 15  # minimum days since first offer


def is_unlocked(completed_offer_count: int, days_since_first_offer: int) -> bool:
    """
    Gate check — call this before predict().
    If False, show the restaurant a progress indicator instead of predictions.
    """
    return (
        completed_offer_count >= UNLOCK_MIN_OFFERS
        and days_since_first_offer >= UNLOCK_MIN_DAYS
    )


# Risk level thresholds (on calibrated probability)
_LOW_THRESH = 0.35  # below → LOW
_HIGH_THRESH = 0.60  # above → HIGH, else MEDIUM

# ── Counterfactual targets ────────────────────────────────────────────────────
# For each actionable feature, defines:
#   - what "improved" value to test
#   - whether the change applies to the ACTIVE offer ('now') or future ones ('next_time')
#
# Features NOT listed here get no counterfactual:
#   - quantity          → food already exists, can't reduce it (platform mission)
#   - sell_through_rate → outcome, not a lever
#   - view_count        → outcome of timing/visibility decisions
#   - engagement_rate   → outcome of content/pricing decisions
_CF_TARGETS: dict[str, tuple] = {
    # (fn that takes current value → suggested value, scope)
    "discount_rate": (lambda v: min(v + 15.0, 62.0), "now"),
    "description_length": (lambda v: 120.0, "now"),
    "time_to_pickup_hours": (lambda v: 3.0, "next_time"),
    "pickup_hour": (lambda v: 12.0, "next_time"),
    "day_of_week": (lambda v: 5.0, "next_time"),  # Friday
}

# Features that improve model accuracy but are NOT actionable by the restaurant.
# They must never appear in top_factors — there is no tip we can give for them.
_NON_ACTIONABLE = frozenset(
    {
        "establishment_type",  # can't change the business type
        "category_sell_rate",  # market-level stat, not controllable per offer
        "restaurant_avg_rating",  # long-term reputation, not a per-offer lever
        "restaurant_past_expired_rate",  # historical track record, not changeable now
        "visibility",  # identity disclosure is a business/privacy decision,
        # NOT a sales lever — hiding identity hurts trust
    }
)


# ─────────────────────────────────────────────────────────────────────────────
class OfferRiskPredictor:
    """
    Scores a batch of active offers, explains each risk score,
    and provides model-based counterfactual estimates per risk factor.

    Output DataFrame columns
    ------------------------
    offer_id    : identifier passed in the input
    risk_score  : calibrated P(expired) in [0.0, 1.0]
    risk_level  : LOW / MEDIUM / HIGH
    top_factors : list of dicts, each containing
                    feature, value, shap_contribution,
                    and counterfactual (or None)
    """

    def __init__(self) -> None:
        if not os.path.exists(MODEL_PATH) or not os.path.exists(ARTIF_PATH):
            raise FileNotFoundError(
                "Model files not found. Run `python train.py` first."
            )
        self._model = CatBoostClassifier()
        self._model.load_model(MODEL_PATH)

        artifacts = joblib.load(ARTIF_PATH)
        self._calibrator = artifacts["calibrator"]
        self._feat_names = artifacts["feature_names"]
        self._cat_idx = artifacts["cat_indices"]
        self._cat_feat_set = set(artifacts.get("cat_features", []))

        print(
            f"✅  Model loaded  "
            f"(test AUC={artifacts['auc_test']}  ECE={artifacts['ece_test']})"
        )

    # ──────────────────────────────────────────────────────────────────────────
    def predict(self, offers: pd.DataFrame) -> pd.DataFrame:
        """
        Score a batch of active offers.

        Parameters
        ----------
        offers : DataFrame with schema columns matching training features.
                 Must include 'offer_id'. 'expired' column is ignored if present.

        Returns
        -------
        DataFrame with: offer_id, risk_score, risk_level, top_factors
        """
        X, _, _, cat_idx = build_features(offers)
        pool = Pool(X, cat_features=cat_idx)

        # Raw probabilities → isotonic calibration → clip to valid range
        raw_proba = self._model.predict_proba(pool)[:, 1]
        cal_proba = np.clip(self._calibrator.predict(raw_proba), 0.0, 1.0)

        # SHAP values — shape (n, n_features + 1); last col is the base value.
        # Explicit np.ndarray cast so Pylance resolves indexing correctly.
        shap_matrix: np.ndarray = np.array(
            self._model.get_feature_importance(pool, type="ShapValues")
        )[:, :-1]

        rows: list[dict] = []
        for idx in range(len(cal_proba)):
            # Cast each row explicitly so _top_factors receives ndarray, not Any
            shap_row: np.ndarray = np.array(shap_matrix[idx])
            feat_row: np.ndarray = np.array(X[idx])
            rows.append(
                {
                    "offer_id": offers["offer_id"].iloc[idx],
                    "risk_score": round(float(cal_proba[idx]), 4),
                    "risk_level": self._risk_level(cal_proba[idx]),
                    "top_factors": self._top_factors(
                        shap_row,
                        feat_row,
                        self._feat_names,
                        self._cat_feat_set,
                        current_score=float(cal_proba[idx]),
                    ),
                }
            )

        return pd.DataFrame(rows)

    # ──────────────────────────────────────────────────────────────────────────
    @staticmethod
    def _risk_level(score: float) -> str:
        if score < _LOW_THRESH:
            return "LOW"
        if score < _HIGH_THRESH:
            return "MEDIUM"
        return "HIGH"

    def _cf_score(self, X_row: np.ndarray, feat_idx: int, new_val: float) -> float:
        """Re-score one offer with a single feature replaced by new_val."""
        X_cf = X_row.copy()
        X_cf[feat_idx] = new_val
        raw = self._model.predict_proba(Pool([X_cf], cat_features=self._cat_idx))[:, 1]
        return float(np.clip(self._calibrator.predict(raw), 0.0, 1.0))

    def _top_factors(
        self,
        shap_row: np.ndarray,
        feat_values: np.ndarray,
        feat_names: list[str],
        cat_feat_set: set[str],
        current_score: float,
        top_n: int = 3,
    ) -> list[dict]:
        """
        Return the top_n ACTIONABLE features driving expiration risk,
        each enriched with a counterfactual prediction where applicable.

        Filters:
          1. Negative SHAP  : feature is helping the offer, excluded.
          2. Non-actionable : restaurant cannot act on it, excluded.
          3. No counterfactual for quantity -- reducing food defeats the
             platform mission. The tip layer redirects to discount instead.
        """
        risk_shap = np.where(shap_row > 0.0, shap_row, 0.0)
        risk_shap = np.where(
            [f not in _NON_ACTIONABLE for f in feat_names],
            risk_shap,
            0.0,
        )
        top_idx = np.argsort(risk_shap)[::-1][:top_n]

        factors: list[dict] = []
        for i in top_idx:
            if risk_shap[i] == 0.0:
                continue

            name = feat_names[i]
            raw = feat_values[i]

            # Human-readable display value
            if name == "view_count_log":
                display_name = "view_count"
                display_val = int(round(float(np.expm1(float(raw)))))
            elif name in cat_feat_set:
                display_name = name
                display_val = str(raw)
            else:
                display_name = name
                display_val = round(float(raw), 4)

            # ── Counterfactual ───────────────────────────────────────────────
            cf = None
            if name in _CF_TARGETS:
                cf_fn, scope = _CF_TARGETS[name]
                suggested = round(float(cf_fn(float(raw))), 2)
                # Only compute if the suggestion meaningfully differs from current
                if abs(suggested - float(raw)) > 0.5:
                    cf_predicted = round(self._cf_score(feat_values, i, suggested), 4)
                    cf = {
                        "suggested_value": suggested,
                        "predicted_score": cf_predicted,
                        "risk_reduction": round(current_score - cf_predicted, 4),
                        "scope": scope,
                    }

            factors.append(
                {
                    "feature": display_name,
                    "value": display_val,
                    "shap_contribution": round(float(risk_shap[i]), 4),
                    "counterfactual": cf,
                }
            )

        return factors


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    from generator import generate_offers, generate_restaurants

    predictor = OfferRiskPredictor()

    # Build a small demo batch (20 offers, drop the label — predictor never sees it)
    restaurants = generate_restaurants(n=80, seed=42)
    demo_df = generate_offers(restaurants, n_offers=20, seed=99)
    ground_truth = demo_df["expired"].tolist()
    demo_df = demo_df.drop(columns=["expired"], errors="ignore")

    results = predictor.predict(demo_df)

    sep = "─" * 70
    print(f"\n{sep}")
    print("  Hourly Risk Check — Demo (20 active offers)")
    print(sep)
    for idx, (_, row) in enumerate(results.iterrows()):
        actual = "X EXPIRED" if ground_truth[idx] else "SOLD"
        print(
            f"\n  {row['offer_id']}  score={row['risk_score']:.3f}  "
            f"level={row['risk_level']:6s}  actual={actual}"
        )
        for f in row["top_factors"]:
            print(
                f"    ⚠  {f['feature']:<35s} "
                f"val={f['value']}  "
                f"SHAP=+{f['shap_contribution']:.4f}"
            )
    print(sep)

    # Summary counts
    counts = results["risk_level"].value_counts()
    print(f"\n  Risk distribution: {counts.to_dict()}")
    print(sep)
