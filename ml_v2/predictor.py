"""
Inference engine for the offer expiration risk model.

Load once, call predict() on every hourly batch of active offers.
Returns a calibrated risk score, a risk level, and the top features
driving that risk — ready to feed a tip generator downstream.

Improvements over v1:
  - Dynamic discount counterfactuals: min delta that achieves meaningful reduction
  - day_of_week tip rewritten: advises quantity reduction on high-expiry days
    instead of suggesting a different day (surplus cannot be scheduled)
  - Contextual pickup_hour tip: best hour per establishment type, data-driven
  - time_to_pickup tip enriched: lead_time_gap_hours + incentive field added
  - Optimal description_length and time_to_pickup loaded from training artifacts
  - prediction_confidence: LOW / MEDIUM / HIGH based on restaurant_offer_count

Usage (standalone demo):
    python predictor.py   (requires trained model from train.py)
"""

import logging
import os

import joblib
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier, Pool
from features import ALL_FEATURES, build_features

logger = logging.getLogger(__name__)

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

# ── Discount counterfactual — min-meaningful-delta strategy ──────────────────
# We test a range of deltas and pick the SMALLEST one that achieves a
# meaningful risk reduction (>= _DISCOUNT_MIN_MEANINGFUL_REDUCTION).
# If no delta clears that bar, we fall back to whichever gives the best
# absolute reduction. This avoids suggesting large discounts when a
# small nudge is enough, and avoids suggesting tiny discounts that do nothing.
_DISCOUNT_DELTAS: list[float] = [5.0, 10.0, 15.0, 20.0, 25.0]
_DISCOUNT_CAP: float = 62.0  # never suggest above this
_DISCOUNT_MIN_MEANINGFUL_REDUCTION: float = 0.10  # 10 pp of risk — worth acting on

# ── Best-day constants — kept for backward compat (loaded from artifacts) ──────────
# No longer used for tip generation: day_of_week now drives quantity advice
# (see _qty_advice_for_day). Restaurants cannot schedule surplus production.
_BEST_DAYS_BY_ESTAB: dict[str, list[int]] = {
    "BAKERY": [5, 6, 4],
    "CAFE": [5, 6, 4],
    "FAST_FOOD": [4, 5, 3],
    "RESTAURANT": [4, 5, 6],
    "FOOD_TRUCK": [5, 4, 6],
    "CATERING": [4, 5, 3],
}
_BEST_DAYS_DEFAULT: list[int] = [4, 5, 6]

# ── Day name lookups — module-level to avoid recreating at every call ─────────
_DAY_NAMES: list[str] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
_DAY_NAMES_FR: list[str] = [
    "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche"
]

# ── All 7 days — kept for internal use ────────────────────────────────────────
_ALL_DAYS: list[int] = list(range(7))


def _fmt_h(hours: float) -> str:
    """Format a duration for tip messages: 0.5 → '30 min', 1.0 → '1h', 2.5 → '2h30'."""
    if hours < 1.0:
        return f"{int(round(hours * 60))} min"
    h = int(hours)
    m = int(round((hours - h) * 60))
    return f"{h}h" if m == 0 else f"{h}h{m:02d}"

# ── Quantity advice by day — thresholds ─────────────────────────────────────
# Minimum expired rate on a given (estab, day) before we suggest reducing
# quantity. 0.40 = "4 out of 10 times you post on this day, the offer expires."
_DAY_EXPIRED_RATE_THRESHOLD: float = 0.40
# Minimum number of historical offers on this (estab, day) bucket before we
# trust the expired_rate enough to make a recommendation.
_DAY_MIN_SAMPLES: int = 20  # matches _MIN_GROUP_SAMPLES in train.py — consistent floor

# ── Static fallback targets for description and lead time ────────────────────
# These are used ONLY when the training artifacts don't contain data-driven
# optimal values (e.g. model trained before that feature was added).
# In normal operation, self._optimal_desc_by_estab and
# self._optimal_ttp_by_estab loaded from artifacts take precedence.
#
# Features NOT handled here (no counterfactual generated):
#   - quantity          → food already exists, can't reduce it (platform mission)
#   - sell_through_rate → outcome, not a lever
#   - view_count        → outcome of timing/visibility decisions
#   - engagement_rate   → outcome of content/pricing decisions
_OPTIMAL_DESC_DEFAULT: float = 120.0
_OPTIMAL_TTP_DEFAULT: float = 3.0

# ── Confidence thresholds based on restaurant_offer_count ────────────────────
_CONF_MEDIUM_MIN = 30  # need at least 30 offers for MEDIUM confidence
_CONF_HIGH_MIN = 100  # need at least 100 offers for HIGH confidence

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
    offer_id             : identifier passed in the input
    risk_score           : calibrated P(expired) in [0.0, 1.0]
    risk_level           : LOW / MEDIUM / HIGH
    prediction_confidence: LOW / MEDIUM / HIGH — reliability based on
                           restaurant_offer_count (history depth)
    top_factors          : list of dicts, each containing
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

        # Data-driven lookup tables — computed from training data in train.py.
        # Fall back to the hardcoded module-level constants if absent
        # (e.g. model was trained before this feature was added).
        self._best_days_by_estab: dict[str, list[int]] = artifacts.get(
            "best_days_by_estab", _BEST_DAYS_BY_ESTAB
        )
        # Data-driven optimal values for description length and lead time.
        # Fall back to module-level constants if absent (old model artifact).
        self._optimal_desc_by_estab: dict[str, float] = artifacts.get(
            "optimal_desc_by_estab", {}
        )
        self._optimal_ttp_by_estab: dict[str, float] = artifacts.get(
            "optimal_ttp_by_estab", {}
        )
        # Quantity advice per (establishment_type, day_of_week) — estab-level fallback.
        # Structure: {estab_type: {day_of_week: {expired_rate, suggested_qty, n_total}}}
        # Fall back to empty dict — no tip generated when absent (old artifacts).
        self._qty_advice_by_day: dict[str, dict[int, dict]] = artifacts.get(
            "qty_advice_by_day", {}
        )
        # Per-restaurant per-day quantity advice — more accurate than estab-level.
        # Structure: {restaurant_id: {day_of_week: {expired_rate, suggested_qty, n_total}}}
        # Consulted first; estab-level is the fallback when absent or n_total < threshold.
        self._qty_advice_by_restaurant_day: dict[str, dict[int, dict]] = artifacts.get(
            "qty_advice_by_restaurant_day", {}
        )
        # Precompute feature indices once — avoids O(n) .index() scan per offer.
        try:
            self._feat_idx_qty: int = self._feat_names.index("quantity")
        except ValueError:
            self._feat_idx_qty = -1  # graceful fallback — quantity tip will be skipped
        try:
            self._feat_idx_ttp: int = self._feat_names.index("time_to_pickup_hours")
        except ValueError:
            self._feat_idx_ttp = -1  # graceful fallback — declare-earlier tip skipped

        data_driven = "best_days_by_estab" in artifacts
        desc_driven = "optimal_desc_by_estab" in artifacts
        qty_driven = "qty_advice_by_day" in artifacts
        rest_qty_driven = "qty_advice_by_restaurant_day" in artifacts
        logger.info(
            "Model loaded  (AUC=%.4f  ECE=%.4f  tables=%s  desc/ttp=%s  qty_day=%s  qty_rest=%s)",
            artifacts["auc_test"],
            artifacts["ece_test"],
            "data-driven" if data_driven else "fallback",
            "data-driven" if desc_driven else "fallback",
            "data-driven" if qty_driven else "fallback",
            "data-driven" if rest_qty_driven else "fallback",
        )

    # ──────────────────────────────────────────────────────────────────────────
    def predict(self, offers: pd.DataFrame, top_n: int = 3) -> pd.DataFrame:
        """
        Score a batch of active offers.

        Parameters
        ----------
        offers : DataFrame with schema columns matching training features.
                 Must include 'offer_id'. 'expired' column is ignored if present.
        top_n  : Number of top actionable risk factors to return per offer.
                 Default is 3. Increase to 5 for a more detailed explanation.

        Returns
        -------
        DataFrame with: offer_id, risk_score, risk_level, prediction_confidence, top_factors

        prediction_confidence reflects how much history the restaurant has:
          LOW    → restaurant_offer_count < 30  (recently unlocked, use with caution)
          MEDIUM → restaurant_offer_count < 100
          HIGH   → restaurant_offer_count >= 100

        Raises
        ------
        ValueError : if top_n < 1 or required columns are missing from offers.
        """
        # ── Input validation ──────────────────────────────────────────────────
        if top_n < 1:
            raise ValueError(f"top_n must be >= 1, got {top_n}.")
        # Validate ALL columns that build_features() or manual extraction need.
        # This prevents silent crashes deep in the stack on malformed payloads.
        required = set(ALL_FEATURES) | {"offer_id", "view_count"}
        missing = required - set(offers.columns)
        if missing:
            raise ValueError(
                f"predict() received a DataFrame missing required columns: {missing}. "
                f"Ensure the offer payload includes all schema fields."
            )

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

        # Vectorise ALL scalar extractions — avoids O(n²) .iloc[idx] inside the loop
        offer_ids: list = offers["offer_id"].tolist()
        offer_counts: list[int] = (
            offers["restaurant_offer_count"].fillna(0).astype(int).tolist()
        )
        estab_types: list[str] = (
            offers["establishment_type"].fillna("UNKNOWN").astype(str).tolist()
        )
        # restaurant_id — optional column (may be absent in minimal payloads)
        restaurant_ids: list[str] = (
            offers["restaurant_id"].fillna("").astype(str).tolist()
            if "restaurant_id" in offers.columns
            else [""] * len(cal_proba)
        )

        rows: list[dict] = []
        for idx in range(len(cal_proba)):
            # Cast each row explicitly so _top_factors receives ndarray, not Any
            shap_row: np.ndarray = np.array(shap_matrix[idx])
            feat_row: np.ndarray = np.array(X[idx])

            offer_count = offer_counts[idx]
            estab_type = estab_types[idx]

            rows.append(
                {
                    "offer_id": offer_ids[idx],
                    "risk_score": round(float(cal_proba[idx]), 4),
                    "risk_level": self._risk_level(cal_proba[idx]),
                    "prediction_confidence": self._prediction_confidence(offer_count),
                    "top_factors": self._top_factors(
                        shap_row,
                        feat_row,
                        self._feat_names,
                        self._cat_feat_set,
                        current_score=float(cal_proba[idx]),
                        estab_type=estab_type,
                        top_n=top_n,
                        restaurant_id=restaurant_ids[idx],
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

    @staticmethod
    def _prediction_confidence(offer_count: int) -> str:
        """
        Reflects how reliable the prediction is based on how much
        history the restaurant has accumulated.

        LOW    → just unlocked (15-29 offers) — treat tips as directional hints
        MEDIUM → growing history (30-99 offers) — reasonably reliable
        HIGH   → mature restaurant (100+ offers) — history features are stable
        """
        if offer_count < _CONF_MEDIUM_MIN:
            return "LOW"
        if offer_count < _CONF_HIGH_MIN:
            return "MEDIUM"
        return "HIGH"

    def _cf_score_batch(
        self, X_row: np.ndarray, feat_idx: int, new_vals: list[float]
    ) -> list[float]:
        """
        Re-score one offer with multiple candidate values for a single feature
        in ONE batched predict_proba call — avoids creating N separate Pool objects.
        The calibrator is also called once on the full result vector (not per row).

        Returns calibrated scores in the same order as new_vals.
        """
        if not new_vals:
            return []
        # Build a matrix with one row per candidate value
        cf_matrix = np.tile(X_row, (len(new_vals), 1))
        for i, val in enumerate(new_vals):
            cf_matrix[i, feat_idx] = val
        raw = self._model.predict_proba(Pool(cf_matrix, cat_features=self._cat_idx))[
            :, 1
        ]
        # Calibrate the whole vector in one call — not per-element
        calibrated = np.clip(self._calibrator.predict(raw), 0.0, 1.0)
        return [float(v) for v in calibrated]

    def _best_discount_cf(
        self,
        X_row: np.ndarray,
        feat_idx: int,
        current_val: float,
        current_score: float,
    ) -> dict | None:
        """
        Min-meaningful-delta strategy:
          1. Test all deltas in _DISCOUNT_DELTAS.
          2. Among those that achieve >= _DISCOUNT_MIN_MEANINGFUL_REDUCTION
             risk reduction, pick the SMALLEST delta (least intrusive tip).
          3. If none clears the threshold, pick the delta with the best
             absolute risk reduction (something is better than nothing).
          4. If no delta improves risk at all, return None.

        This avoids two failure modes:
          - Suggesting a large discount when a small one already solves it.
          - Suggesting a tiny discount that barely moves the needle.
        """
        # Build candidate (delta, suggested_value) pairs — filter capped ones first
        delta_suggested: list[tuple[float, float]] = []
        for delta in _DISCOUNT_DELTAS:
            suggested = min(current_val + delta, _DISCOUNT_CAP)
            if abs(suggested - current_val) >= 0.5:
                delta_suggested.append((delta, suggested))

        if not delta_suggested:
            return None

        # Batch all counterfactual inferences into ONE predict_proba call
        new_vals = [s for _, s in delta_suggested]
        cf_scores = self._cf_score_batch(X_row, feat_idx, new_vals)

        candidates: list[tuple[float, float, float, float]] = []
        # (delta, suggested, cf_score, reduction)
        for (delta, suggested), cf_score in zip(delta_suggested, cf_scores):
            reduction = current_score - cf_score
            if reduction > 0:
                candidates.append((delta, suggested, cf_score, reduction))

        if not candidates:
            return None

        # Prefer smallest delta that crosses the meaningful threshold
        meaningful = [
            c for c in candidates if c[3] >= _DISCOUNT_MIN_MEANINGFUL_REDUCTION
        ]
        if meaningful:
            chosen = min(meaningful, key=lambda c: c[0])
        else:
            # Fallback: only return if best absolute reduction is worth showing.
            # Uses same threshold as all other tip methods (>= 0.01).
            best = max(candidates, key=lambda c: c[3])
            if best[3] < 0.01:
                # Improvement too small to be actionable — suppress the tip
                return None
            chosen = best

        delta, suggested, cf_score, reduction = chosen
        return {
            "suggested_value": round(suggested, 2),
            "predicted_score": round(cf_score, 4),
            "risk_reduction": round(reduction, 4),
            "scope": "now",
            "delta_applied": f"+{delta:.0f}%",
            "message": (
                f"Votre remise de {int(current_val)}% est insuffisante. "
                f"Passez \u00e0 {int(round(suggested))}% (+{int(delta)}%) — "
                f"votre risque d\u2019expiration baisse de {int(round(reduction * 100))} points."
            ),
        }

    def _qty_advice_for_day(
        self,
        X_row: np.ndarray,
        feat_idx_qty: int,
        current_day: int,
        current_qty: float,
        current_score: float,
        estab_type: str,
        restaurant_id: str = "",
    ) -> dict | None:
        """
        When day_of_week is a top risk factor, advise the restaurant to post
        fewer units on this specific day rather than suggesting they reschedule.

        Rationale: restaurants sell surplus — they cannot choose WHICH day surplus
        appears. What they CAN control is HOW MUCH they post. If this day shows a
        persistently high expiration rate, the quantity posted exceeds demand.

        Strategy:
          1. Look up per-restaurant stats for (restaurant_id, current_day) first —
             most accurate, uses this restaurant's own history.
          2. Fall back to estab_type bucket when no restaurant-level data exists
             or when n_total < _DAY_MIN_SAMPLES (insufficient confidence).
          3. Only trigger if expired_rate >= _DAY_EXPIRED_RATE_THRESHOLD (40%)
             AND n_total >= _DAY_MIN_SAMPLES (20 — consistent with all other
             lookup tables in the system).
          4. Only suggest a REDUCTION — never advise posting more units.
          5. Validate via _cf_score_batch: reduced qty must lower the risk score
             by at least 0.01 before the tip is shown.
        """
        # 1. Per-restaurant lookup — most accurate
        day_stats = self._qty_advice_by_restaurant_day.get(restaurant_id, {}).get(
            current_day
        )
        data_source = "restaurant"

        # 2. Fall back to estab_type when restaurant data is absent or too sparse
        if day_stats is None or day_stats["n_total"] < _DAY_MIN_SAMPLES:
            day_stats = self._qty_advice_by_day.get(estab_type, {}).get(current_day)
            data_source = "establishment_type"

        if day_stats is None:
            return None

        if day_stats["n_total"] < _DAY_MIN_SAMPLES:
            return None

        if day_stats["expired_rate"] < _DAY_EXPIRED_RATE_THRESHOLD:
            return None

        suggested_qty = day_stats["suggested_qty"]

        # Only suggest a reduction — never advise posting more
        if suggested_qty >= current_qty:
            return None

        # Validate with the model: does reducing quantity actually lower the risk?
        cf_scores = self._cf_score_batch(X_row, feat_idx_qty, [suggested_qty])
        reduction = current_score - cf_scores[0]

        if reduction < 0.01:
            return None

        day_fr = _DAY_NAMES_FR[current_day]
        pct_expired = int(round(day_stats["expired_rate"] * 100))
        return {
            "suggested_value": int(round(suggested_qty)),
            "current_qty": int(round(current_qty)),
            "expired_rate_on_day": round(day_stats["expired_rate"], 4),
            "n_samples_on_day": day_stats["n_total"],
            "predicted_score": round(cf_scores[0], 4),
            "risk_reduction": round(reduction, 4),
            "scope": "next_time",
            "advice_type": "quantity_by_day",
            "data_source": data_source,
            "message": (
                f"Le {day_fr}, vous expirez {pct_expired}\u202f% de vos offres "
                f"({day_stats['n_total']} analys\u00e9es). "
                f"La prochaine fois un {day_fr}, publiez "
                f"{int(round(suggested_qty))}\u00a0unit\u00e9s au lieu de "
                f"{int(round(current_qty))}."
            ),
        }

    def _best_desc_cf(
        self,
        X_row: np.ndarray,
        feat_idx: int,
        current_val: float,
        current_score: float,
        estab_type: str,
    ) -> dict | None:
        """
        Suggest an optimal description length for this establishment type.
        Target is the median description_length of SOLD offers from training data,
        loaded from artifacts (falls back to _OPTIMAL_DESC_DEFAULT).

        Only generates a tip if:
          - current description is strictly below the target
          - the model confirms a meaningful risk reduction (>= 0.01)
        The proximity guard is intentionally omitted — _cf_score is the
        sole gatekeeper. Even 3 extra characters might matter for some offers.
        """
        target = float(
            self._optimal_desc_by_estab.get(estab_type, _OPTIMAL_DESC_DEFAULT)
        )
        # No tip if already at or above the target
        if current_val >= target:
            return None

        cf_scores = self._cf_score_batch(X_row, feat_idx, [target])
        reduction = current_score - cf_scores[0]

        if reduction < 0.01:
            return None

        return {
            "suggested_value": int(target),
            "predicted_score": round(cf_scores[0], 4),
            "risk_reduction": round(reduction, 4),
            "scope": "now",
            "message": (
                f"Votre description ({int(current_val)}\u00a0car.) est trop courte. "
                f"Les offres similaires vendues font {int(target)}+ caract\u00e8res. "
                f"Enrichissez-la maintenant."
            ),
        }

    def _best_ttp_cf(
        self,
        X_row: np.ndarray,
        feat_idx: int,
        current_val: float,
        current_score: float,
        estab_type: str,
    ) -> dict | None:
        """
        Suggest an optimal time_to_pickup (lead time) for this establishment type.
        Target is the median time_to_pickup_hours of SOLD offers from training data,
        loaded from artifacts (falls back to _OPTIMAL_TTP_DEFAULT).

        Only generates a tip if:
          - current lead time is strictly below the target
          - the model confirms a meaningful risk reduction (>= 0.01)
        The proximity guard is intentionally omitted — _cf_score is the
        sole gatekeeper. Even 30 minutes of extra lead time can matter.
        The scope is always 'next_time' — lead time can't be changed for an active offer.
        """
        target = float(self._optimal_ttp_by_estab.get(estab_type, _OPTIMAL_TTP_DEFAULT))
        # No tip if already at or above the target lead time
        if current_val >= target:
            return None

        cf_scores = self._cf_score_batch(X_row, feat_idx, [target])
        reduction = current_score - cf_scores[0]

        if reduction < 0.01:
            return None

        lead_gap = round(target - current_val, 1)
        return {
            "suggested_value": round(target, 1),
            "lead_time_gap_hours": lead_gap,
            "predicted_score": round(cf_scores[0], 4),
            "risk_reduction": round(reduction, 4),
            "scope": "next_time",
            "incentive": "publish_earlier",
            "message": (
                f"Vous publiez {_fmt_h(current_val)} avant le pickup. "
                f"En publiant {_fmt_h(target)} \u00e0 l\u2019avance "
                f"({_fmt_h(lead_gap)} plus t\u00f4t), "
                f"votre risque d\u2019expiration baisserait de "
                f"{int(round(reduction * 100))}\u00a0points."
            ),
        }

    def _declare_earlier_cf(
        self,
        X_row: np.ndarray,
        feat_idx_ttp: int,
        current_hour: int,
        current_ttp: float,
        current_score: float,
        estab_type: str,
    ) -> dict | None:
        """
        When pickup_hour is a top risk factor (late or low-demand hour), the
        restaurant cannot change WHEN surplus appears. What they CAN do is
        DECLARE EARLIER — post the offer before their service ends with a
        conservative quantity estimate.

        Business logic:
          A restaurant closing at 22h knows at 20h that surplus will remain.
          Instead of waiting until 21:30h (30 min TTP, few people see it),
          they post at 20h with a prudent quantity (e.g. 10 units instead of
          the final 18). Two hours of visibility converts far more orders than
          thirty minutes even with a slightly conservative count.

        Counterfactual: simulates raising time_to_pickup_hours to the optimal
        TTP for this establishment type. The pickup hour itself does NOT change
        — only the lead time does. This is the same lever as _best_ttp_cf but
        triggered by a different SHAP signal (the hour, not the lead time).

        Returns the computed clock time at which the restaurant should post
        (current_pickup_hour − target_ttp), so the frontend can display:
        “At 20h, declare your estimated surplus for a 22h pickup.”
        """
        target_ttp = float(
            self._optimal_ttp_by_estab.get(estab_type, _OPTIMAL_TTP_DEFAULT)
        )
        # No tip if already posting early enough
        if current_ttp >= target_ttp:
            return None

        # Counterfactual: simulate posting target_ttp hours before pickup
        cf_scores = self._cf_score_batch(X_row, feat_idx_ttp, [target_ttp])
        reduction = current_score - cf_scores[0]

        if reduction < 0.01:
            return None

        # Clock time at which the restaurant should post (whole hour, wraps midnight)
        suggested_publish_at = (current_hour - int(round(target_ttp))) % 24

        lead_gap = round(target_ttp - current_ttp, 1)
        return {
            "current_pickup_hour": current_hour,
            "suggested_publish_at": suggested_publish_at,
            "suggested_publish_label": f"{suggested_publish_at:02d}h",
            "current_ttp_hours": round(current_ttp, 1),
            "target_ttp_hours": round(target_ttp, 1),
            "lead_time_gap_hours": lead_gap,
            "predicted_score": round(cf_scores[0], 4),
            "risk_reduction": round(reduction, 4),
            "scope": "next_time",
            "incentive": "declare_earlier_prudent_qty",
            "message": (
                f"Vous avez publi\u00e9 seulement {_fmt_h(current_ttp)} avant "
                f"votre pickup de {current_hour:02d}h. "
                f"La prochaine fois, publiez d\u00e8s {suggested_publish_at:02d}h "
                f"avec une quantit\u00e9 prudente \u2014 vous gagnerez "
                f"{_fmt_h(lead_gap)} de visibilit\u00e9 suppl\u00e9mentaire."
            ),
        }

    def _top_factors(
        self,
        shap_row: np.ndarray,
        feat_values: np.ndarray,
        feat_names: list[str],
        cat_feat_set: set[str],
        current_score: float,
        estab_type: str = "UNKNOWN",
        top_n: int = 3,
        restaurant_id: str = "",
    ) -> list[dict]:
        """
        Return the top_n ACTIONABLE features driving expiration risk,
        each enriched with a counterfactual prediction where applicable.

        Filters:
          1. Negative SHAP     : feature is helping the offer, excluded.
          2. Non-actionable    : restaurant cannot act on it, excluded.
          3. quantity (direct) : no counterfactual when quantity itself is the top
             SHAP factor — food already exists, reducing it defeats the platform
             mission. However when day_of_week is the top factor, the system
             advises quantity reduction on that specific day (indirect path via
             _qty_advice_for_day).

        Counterfactual strategies:
          - discount_rate       : min-meaningful-delta selection
          - day_of_week         : quantity reduction advice for this specific day
                                  per-restaurant history first, estab-type fallback
                                  (surplus cannot be scheduled — we advise HOW MUCH,
                                  not WHEN to post)
          - pickup_hour         : "declare earlier" — simulate publishing
                                  target_ttp hours before the existing pickup;
                                  the hour itself does NOT change, only the
                                  lead time (same lever as time_to_pickup_hours
                                  but triggered by a different SHAP signal)
          - description_length  : median of sold offers per establishment type
          - time_to_pickup_hours: median lead time of sold offers + incentive message
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

            # ── Counterfactual — strategy depends on feature ─────────────────
            cf: dict | None = None

            if name == "discount_rate":
                cf = self._best_discount_cf(feat_values, i, float(raw), current_score)

            elif name == "day_of_week":
                # self._feat_idx_qty precomputed in __init__ — no per-offer .index() scan
                if self._feat_idx_qty >= 0:
                    cf = self._qty_advice_for_day(
                        feat_values,
                        self._feat_idx_qty,
                        int(round(float(raw))),                      # current_day
                        float(feat_values[self._feat_idx_qty]),      # current_qty
                        current_score,
                        estab_type,
                        restaurant_id,
                    )

            elif name == "pickup_hour":
                # Lever: publish earlier for this SAME pickup hour.
                # Modifies time_to_pickup_hours in the counterfactual,
                # not pickup_hour itself (surplus arrives when it arrives).
                if self._feat_idx_ttp >= 0:
                    cf = self._declare_earlier_cf(
                        feat_values,
                        self._feat_idx_ttp,
                        int(round(float(raw))),               # current_hour
                        float(feat_values[self._feat_idx_ttp]),  # current_ttp
                        current_score,
                        estab_type,
                    )

            elif name == "description_length":
                cf = self._best_desc_cf(
                    feat_values, i, float(raw), current_score, estab_type
                )

            elif name == "time_to_pickup_hours":
                cf = self._best_ttp_cf(
                    feat_values, i, float(raw), current_score, estab_type
                )

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
