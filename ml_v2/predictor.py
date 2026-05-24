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
  - Contextual visibility/demand tips for low-engagement and low-demand offers
"""

import logging
import os

import joblib
import numpy as np
import pandas as pd
from catboost import CatBoostClassifier, Pool
from features import ALL_FEATURES, build_features
from diagnosis import OfferDiagnosis, diagnose, diagnosis_summary
from interaction_engine import detect_interactions
from optimizer import optimize_offer

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

# ── Contextual tip thresholds — REMOVED ─────────────────────────────────────────
# All contextual tip triggering is now 100 % SHAP-driven via OfferDiagnosis.
# No feature value is compared to a hardcoded constant to decide whether a
# tip fires. The model’s learned weights drive every trigger decision.


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
        self._feature_bounds_by_estab: dict[str, dict[str, dict[str, float]]] = artifacts.get(
            "feature_bounds_by_estab", {}
        )
        self._global_interaction_matrix = artifacts.get(
            "global_interaction_matrix", None
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
        # Precompute indices for contextual-tip features — same pattern.
        try:
            self._feat_idx_view_log: int = self._feat_names.index("view_count")
        except ValueError:
            self._feat_idx_view_log = -1
        try:
            self._feat_idx_engagement: int = self._feat_names.index("engagement_rate")
        except ValueError:
            self._feat_idx_engagement = -1
        try:
            self._feat_idx_cat_sell: int = self._feat_names.index("category_sell_rate")
        except ValueError:
            self._feat_idx_cat_sell = -1
        # Indices for qty_compensator_cf — leverage these rather than .index() at runtime
        try:
            self._feat_idx_discount: int = self._feat_names.index("discount_rate")
        except ValueError:
            self._feat_idx_discount = -1
        try:
            self._feat_idx_desc: int = self._feat_names.index("description_length")
        except ValueError:
            self._feat_idx_desc = -1

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

            current_score = float(cal_proba[idx])
            risk_level = self._risk_level(current_score)

            # SHAP-driven diagnosis — computed once per offer, shared with
            # _top_factors so tip triggering is model-derived, not rule-based.
            diag: OfferDiagnosis = diagnose(shap_row, self._feat_names)

            top_factors = self._top_factors(
                shap_row,
                feat_row,
                self._feat_names,
                self._cat_feat_set,
                current_score=current_score,
                estab_type=estab_type,
                # HIGH offers get more factors explained (5 vs default)
                top_n=5 if risk_level == "HIGH" else top_n,
                restaurant_id=restaurant_ids[idx],
                diagnosis=diag,
            )

            action_plan = None
            if risk_level in {"HIGH", "MEDIUM"}:
                current_values = {f: float(feat_row[i]) for i, f in enumerate(self._feat_names) if f not in self._cat_feat_set}

                # quantity IS included here for interaction detection only:
                # knowing that quantity x discount_rate interact tells the
                # optimizer "a bigger discount is especially powerful when
                # the restaurant has a lot of surplus to move".
                # quantity is NOT passed to optimize_offer (surplus already
                # exists; reducing it means waste, not the platform mission).
                _detect_actionable = {"discount_rate", "description_length",
                                      "time_to_pickup_hours", "quantity"}
                single_pool = Pool(X[idx:idx+1], cat_features=self._cat_idx)
                interacting_pairs = detect_interactions(
                    self._model, single_pool, self._feat_names,
                    _detect_actionable, threshold=0.01
                )

                top_shap_features = [f["feature"] for f in top_factors if f.get("shap_contribution", 0) > 0]

                # HIGH targets standard threshold (35%); MEDIUM targets a
                # stricter 25% so the plan still shows a meaningful gain.
                _target = 0.35 if risk_level == "HIGH" else 0.25
                action_plan = optimize_offer(
                    self,
                    X_row=feat_row,
                    current_score=current_score,
                    top_shap_features=top_shap_features,
                    interacting_pairs=interacting_pairs,
                    estab_type=estab_type,
                    feature_names=self._feat_names,
                    current_values=current_values,
                    estab_bounds=self._feature_bounds_by_estab.get(estab_type, {}),
                    target_risk=_target,
                )

            rows.append(
                {
                    "offer_id": offer_ids[idx],
                    "risk_score": round(current_score, 4),
                    "risk_level": risk_level,
                    "prediction_confidence": self._prediction_confidence(offer_count),
                    "top_factors": top_factors,
                    "action_plan": action_plan,
                    # SHAP-derived diagnosis — ready for downstream display / API
                    "diagnosis": {
                        "primary": diag.primary.name if diag.primary else None,
                        "axes": [
                            {"name": a.name, "label": a.label_fr, "share": a.share}
                            for a in diag.dominant_axes
                        ],
                        "summary": diagnosis_summary(diag),
                    } if diag.axes else None,
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
        _ci = int(current_val)
        _si = int(round(suggested))
        _di = int(delta)
        _rp = int(round(reduction * 100))
        if current_val < 25:
            _disc_msg = (
                f"\u00c0 {_ci}%\u00a0de remise, votre offre peine \u00e0 se d\u00e9marquer. "
                f"Passer \u00e0 {_si}% (+{_di}%) devrait stimuler les commandes \u2014 "
                f"{_rp}\u00a0points de risque en moins."
            )
        elif delta <= 5.0:
            _disc_msg = (
                f"Bonne nouvelle\u00a0: un simple +{_di}% suffit ici. "
                f"Passer de {_ci}% \u00e0 {_si}% de remise r\u00e9duit votre risque de {_rp}\u00a0points."
            )
        elif _rp >= 20:
            _disc_msg = (
                f"Un effort sur la remise paie vraiment\u00a0: {_ci}% \u2192 {_si}% "
                f"fait chuter votre risque de {_rp}\u00a0points."
            )
        elif current_val >= 48:
            _disc_msg = (
                f"M\u00eame \u00e0 {_ci}%, la demande reste insuffisante. "
                f"Pousser jusqu\u2019\u00e0 {_si}% (+{_di}%) peut encore faire la diff\u00e9rence\u00a0: "
                f"-{_rp}\u00a0pts de risque."
            )
        else:
            _disc_msg = (
                f"Votre remise de {_ci}% est insuffisante. "
                f"Passez \u00e0 {_si}% (+{_di}%) \u2014 "
                f"votre risque d\u2019expiration baisse de {_rp}\u00a0points."
            )
        return {
            "suggested_value": round(suggested, 2),
            "predicted_score": round(cf_score, 4),
            "risk_reduction": round(reduction, 4),
            "scope": "now",
            "delta_applied": f"+{delta:.0f}%",
            "message": _disc_msg,
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
            # Next-time planning advice: the restaurant chooses how many
            # units to POST on the platform for the next occurrence of this day.
            "message": (
                (
                    f"Le {day_fr} est un jour difficile pour vous\u00a0: {pct_expired}\u202f% de vos offres expirent "
                    f"({day_stats['n_total']} analys\u00e9es). "
                    f"La prochaine fois un {day_fr}, pr\u00e9voyez de publier {int(round(suggested_qty))}\u00a0unit\u00e9s "
                    f"au lieu de {int(round(current_qty))} pour correspondre \u00e0 la demande r\u00e9elle de ce jour."
                ) if pct_expired >= 60 else (
                    f"Le {day_fr}, {pct_expired}\u202f% de vos offres expirent en moyenne "
                    f"({day_stats['n_total']} analys\u00e9es). "
                    f"La prochaine fois ce jour-l\u00e0, planifiez {int(round(suggested_qty))}\u00a0unit\u00e9s "
                    f"pour mieux correspondre \u00e0 la demande."
                )
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
                (
                    f"Description tr\u00e8s courte ({int(current_val)}\u00a0car.)\u00a0: "
                    f"les clients ne savent pas ce qu\u2019ils ach\u00e8tent. "
                    f"D\u00e9crivez le contenu, les portions et les points forts \u2014 "
                    f"visez {int(target)}+ car."
                ) if current_val < 40 else (
                    f"Votre description ({int(current_val)}\u00a0car.) manque de d\u00e9tails. "
                    f"Les offres similaires vendues font {int(target)}+ car. "
                    f"Ajoutez ingr\u00e9dients, portions ou particularit\u00e9s pour rassurer le client."
                ) if current_val < 90 else (
                    f"Quelques d\u00e9tails suppl\u00e9mentaires feraient la diff\u00e9rence. "
                    f"\u00c9toffez de {int(current_val)} \u00e0 {int(target)}+ car. avec ce qui distingue votre offre."
                )
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
                (
                    f"Vous publiez seulement {_fmt_h(current_val)} avant le pickup. "
                    f"En annon\u00e7ant {_fmt_h(lead_gap)} plus t\u00f4t, "
                    f"les clients ont le temps de planifier leur passage \u2014 "
                    f"risque en baisse de {int(round(reduction * 100))}\u00a0points."
                ) if lead_gap >= 1.5 else (
                    f"Vous publiez {_fmt_h(current_val)} avant le pickup. "
                    f"En publiant {_fmt_h(target)} \u00e0 l\u2019avance "
                    f"({_fmt_h(lead_gap)} plus t\u00f4t), votre risque baisserait de "
                    f"{int(round(reduction * 100))}\u00a0points."
                )
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
        "At 20h, declare your estimated surplus for a 22h pickup."
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

    # ── Contextual tip helpers ────────────────────────────────────────────────

    def _qty_compensator_cf(
        self,
        X_row: np.ndarray,
        current_qty: float,
        current_score: float,
        estab_type: str,
    ) -> dict | None:
        """
        Surplus context: quantity cannot be reduced on an active offer.

        Uses the SHAP global interaction matrix (learned at training time over
        all training offers) to identify which actionable lever is most strongly
        coupled with quantity. High interaction strength means: when stock is
        large, THIS feature has an outsized effect on whether the offer sells.

        The recommendation is 100 % model-driven — no hardcoded lever priority.
        If discount x quantity has the strongest interaction, discount is suggested.
        If description x quantity is stronger, description is suggested instead.
        """
        if self._feat_idx_qty < 0:
            return None

        qty_idx = self._feat_idx_qty

        # Candidate levers and their precomputed feature indices
        _levers: list[tuple[str, int]] = [
            ("discount_rate",        self._feat_idx_discount),
            ("description_length",   self._feat_idx_desc),
            ("time_to_pickup_hours", self._feat_idx_ttp),
        ]
        _levers = [(n, idx) for n, idx in _levers if idx >= 0]
        if not _levers:
            return None

        # Select lever with highest SHAP interaction strength vs quantity
        best_feat, best_idx, best_strength = _levers[0][0], _levers[0][1], 0.0
        if self._global_interaction_matrix is not None:
            mat = self._global_interaction_matrix
            for feat_name, feat_idx in _levers:
                if qty_idx < mat.shape[0] and feat_idx < mat.shape[1]:
                    strength = float(mat[qty_idx, feat_idx])
                    if strength > best_strength:
                        best_strength = strength
                        best_feat = feat_name
                        best_idx = feat_idx

        qty_int = int(round(current_qty))

        # Generate a counterfactual for the winning lever
        if best_feat == "discount_rate":
            base = self._best_discount_cf(
                X_row, best_idx, float(X_row[best_idx]), current_score
            )
            if base is None:
                return None
            sug = int(round(base["suggested_value"]))
            red = int(round(base["risk_reduction"] * 100))
            return {
                **base,
                "advice_type": "qty_compensator",
                "compensated_by": best_feat,
                "interaction_strength": round(best_strength, 4),
                "message": (
                    f"Vous avez {qty_int}\u00a0unit\u00e9s \u00e0 \u00e9couler. "
                    f"Le mod\u00e8le indique que la remise est votre levier le plus puissant "
                    f"pour ce volume \u2014 passer \u00e0 {sug}% r\u00e9duit votre risque de {red}\u00a0pts."
                ),
            }

        elif best_feat == "description_length":
            base = self._best_desc_cf(
                X_row, best_idx, float(X_row[best_idx]), current_score, estab_type
            )
            if base is None:
                return None
            sug = int(round(base["suggested_value"]))
            return {
                **base,
                "advice_type": "qty_compensator",
                "compensated_by": best_feat,
                "interaction_strength": round(best_strength, 4),
                "message": (
                    f"Pour \u00e9couler vos {qty_int}\u00a0unit\u00e9s, "
                    f"une description compl\u00e8te est particuli\u00e8rement d\u00e9cisive selon le mod\u00e8le. "
                    f"Visez {sug}+\u00a0car. pour maximiser l\u2019attractivit\u00e9."
                ),
            }

        elif best_feat == "time_to_pickup_hours":
            base = self._best_ttp_cf(
                X_row, best_idx, float(X_row[best_idx]), current_score, estab_type
            )
            if base is None:
                return None
            sug = round(base["suggested_value"], 1)
            red = int(round(base["risk_reduction"] * 100))
            return {
                **base,
                "advice_type": "qty_compensator",
                "compensated_by": best_feat,
                "interaction_strength": round(best_strength, 4),
                "message": (
                    f"Avec {qty_int}\u00a0unit\u00e9s, le temps d\u2019exposition est crucial. "
                    f"La prochaine fois, publiez {sug}h avant le pickup "
                    f"pour donner \u00e0 vos clients le temps de commander (\u2212{red}\u00a0pts)."
                ),
            }

        return None

    def _visibility_content_cf(
        self,
        view_count: float,
        engagement_rate: float,
        diagnosis: OfferDiagnosis | None = None,
    ) -> dict | None:
        """
        Content-quality tip — only called from the SHAP-triggered path in
        _top_factors (never from a static fallback).

        Message selection is 100 % SHAP-driven:
          - visibility axis share > engagement axis share
            → "presque invisible" message (view count is the bottleneck)
          - engagement axis share > visibility axis share
            → "ne cliquent pas" message (CTR is the bottleneck)
          - neither dominates
            → generic attractiveness message

        No hardcoded view-count or engagement-rate thresholds are used
        for branching — the SHAP axis shares decide the message.
        """
        raw_views = int(round(np.expm1(view_count)))
        engagement_pct = round(engagement_rate * 100, 1)

        vis_share = diagnosis.axis_share("visibility") if diagnosis else 0.0
        eng_share = diagnosis.axis_share("engagement") if diagnosis else 0.0

        if vis_share >= eng_share and vis_share > 0:
            # Visibility (view count) is the dominant content-quality driver
            _vis_msg = (
                f"Votre offre est presque invisible ({raw_views}\u00a0vues). "
                "Ajoutez une photo app\u00e9tissante et d\u00e9taillez le contenu \u2014 "
                "l\u2019impact sur les vues sera imm\u00e9diat."
            )
        elif eng_share > vis_share:
            # Engagement (CTR) is the dominant content-quality driver
            _vis_msg = (
                f"Les clients voient votre offre mais ne cliquent pas "
                f"({engagement_pct}\u202f% d\u2019engagement). "
                "Un titre plus accrocheur, une photo claire ou un d\u00e9tail concret "
                "(portions, ingr\u00e9dients, poids) pourraient inverser la tendance."
            )
        else:
            _vis_msg = (
                "Votre offre manque d\u2019attractivit\u00e9. "
                "Enrichissez la description et soignez la photo de couverture "
                "pour augmenter les vues et l\u2019engagement."
            )
        return {
            "scope": "now",
            "advice_type": "content_quality",
            "message": _vis_msg,
        }

    def _low_demand_discount_cf(
        self,
        X_row: np.ndarray,
        feat_idx_discount: int,
        current_discount: float,
        current_qty: float,
        current_score: float,
        category_sell_rate: float,
        cat_axis_share: float = 0.0,
    ) -> dict | None:
        """
        Weak-category discount tip — delegates to _best_discount_cf for the
        model inference, then replaces the message with a SHAP-enriched
        explanation of WHY the discount is especially important here.

        Always called from _top_factors’ SHAP-driven path (category axis >= 15 %).
        No static trigger logic in this method — the trigger is upstream.

        cat_axis_share: fraction of total SHAP attributed to the category axis;
          used to quantify the category’s contribution in the message.
        """
        if feat_idx_discount < 0:
            return None

        base_cf = self._best_discount_cf(
            X_row, feat_idx_discount, current_discount, current_score
        )
        if base_cf is None:
            return None

        suggested = int(round(base_cf["suggested_value"]))
        delta = base_cf.get("delta_applied", "")
        reduction_pts = int(round(base_cf["risk_reduction"] * 100))
        contextual_cf = dict(base_cf)
        contextual_cf["advice_type"] = "low_demand_discount"

        # SHAP-enriched message: quantify the category's contribution when available
        if cat_axis_share > 0:
            _cat_pct = int(round(cat_axis_share * 100))
            contextual_cf["message"] = (
                f"La cat\u00e9gorie repr\u00e9sente {_cat_pct}\u202f% de votre risque d\u2019expiration. "
                f"Pour compenser cette faible demande, passer \u00e0 {suggested}\u202f% "
                f"de remise ({delta}) r\u00e9duirait votre risque de {reduction_pts}\u202fpoints."
            )
        else:
            contextual_cf["message"] = (
                "Cette cat\u00e9gorie g\u00e9n\u00e8re habituellement moins de demande. "
                f"Passer \u00e0 {suggested}\u202f% de remise ({delta}) "
                f"pourrait r\u00e9duire votre risque de {reduction_pts}\u202fpoints."
            )
        return contextual_cf

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
        diagnosis: OfferDiagnosis | None = None,
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

        Contextual tips (appended after SHAP-based counterfactuals, max 1 each):
          - content_quality     : low views/engagement in a popular category
                                  → improve description & photo (no model inference)
          - low_demand_discount : low-demand category + high quantity
                                  → deeper discount (reuses _best_discount_cf)
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
            if name == "view_count":
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

            elif name == "quantity":
                # Surplus context: the food already exists — we cannot advise
                # the restaurant to reduce it. Instead, query the SHAP global
                # interaction matrix to find which actionable lever is most
                # powerful at clearing a large stock, and generate a tip for it.
                cf = self._qty_compensator_cf(
                    feat_values, float(raw), current_score, estab_type
                )

            factors.append(
                {
                    "feature": display_name,
                    "value": display_val,
                    "shap_contribution": round(float(risk_shap[i]), 4),
                    "counterfactual": cf,
                }
            )

        # ── Contextual tips — appended AFTER SHAP-based factors ──────────────
        # These complement model explanations with business heuristics.
        # Rules:
        #   • Only append if the equivalent advice_type is not already present.
        #   • Cap total factors at top_n + 2 to avoid overwhelming the UI.
        #     (top_n covers SHAP factors; +2 reserves slots for both contextual tips.)
        #   • Each tip gets a sentinel shap_contribution of 0.0 to signal it is
        #     heuristic, not model-derived — clients can filter on this field.

        existing_advice_types: set[str] = {
            f["counterfactual"].get("advice_type", "")
            for f in factors
            if f.get("counterfactual")
        }

        # ── Extract raw feature values needed for contextual checks ──────────
        # Use precomputed indices; fall back to safe defaults when absent.
        view_log_val: float = (
            float(feat_values[self._feat_idx_view_log])
            if self._feat_idx_view_log >= 0
            else 0.0  # safe worst-case: no views observed
        )
        engagement_val: float = (
            float(feat_values[self._feat_idx_engagement])
            if self._feat_idx_engagement >= 0
            else 0.0  # safe worst-case: no engagement observed
        )
        cat_sell_val: float = (
            float(feat_values[self._feat_idx_cat_sell])
            if self._feat_idx_cat_sell >= 0
            else 0.5  # neutral default — neither tip fires
        )
        current_qty: float = (
            float(feat_values[self._feat_idx_qty])
            if self._feat_idx_qty >= 0
            else 0.0
        )

        # Look up the discount_rate feature index on the fly (not precomputed
        # because it may not always be a top SHAP factor).
        try:
            feat_idx_discount: int = feat_names.index("discount_rate")
        except ValueError:
            feat_idx_discount = -1

        current_discount: float = (
            float(feat_values[feat_idx_discount])
            if feat_idx_discount >= 0
            else 0.0
        )

        # CASE 1 — Content quality tip (purely SHAP-driven, no static fallback)
        # Fires when the diagnosis shows visibility or engagement is a significant
        # risk axis (>=15 % share) AND category is not the primary bottleneck.
        # shap_contribution = actual combined SHAP of the two axes (not 0.0).
        if "content_quality" not in existing_advice_types and diagnosis is not None:
            if (
                (
                    diagnosis.has_axis("visibility", min_share=0.15)
                    or diagnosis.has_axis("engagement", min_share=0.15)
                )
                and not diagnosis.is_primary("category")
            ):
                vis_cf = self._visibility_content_cf(
                    view_log_val, engagement_val, diagnosis=diagnosis
                )
                if vis_cf is not None:
                    _vis_shap = sum(
                        a.shap_sum for a in diagnosis.axes
                        if a.name in {"visibility", "engagement"}
                    )
                    factors.append(
                        {
                            "feature": "visibility_engagement",
                            "value": round(engagement_val, 4),
                            "shap_contribution": round(_vis_shap, 4),
                            "counterfactual": vis_cf,
                        }
                    )

        # CASE 2 — Weak-category discount tip (purely SHAP-driven, no static fallback)
        # Fires when category axis >= 15 % of total expiration risk.
        # shap_contribution = actual SHAP of the category axis (not 0.0).
        if "low_demand_discount" not in existing_advice_types and diagnosis is not None:
            _cat_share = diagnosis.axis_share("category")
            if diagnosis.has_axis("category", min_share=0.15) and feat_idx_discount >= 0:
                demand_cf = self._low_demand_discount_cf(
                    feat_values,
                    feat_idx_discount,
                    current_discount,
                    current_qty,
                    current_score,
                    cat_sell_val,
                    cat_axis_share=_cat_share,
                )
                if demand_cf is not None:
                    _cat_shap = next(
                        (a.shap_sum for a in diagnosis.axes if a.name == "category"), 0.0
                    )
                    factors.append(
                        {
                            "feature": "category_demand",
                            "value": round(cat_sell_val, 4),
                            "shap_contribution": round(_cat_shap, 4),
                            "counterfactual": demand_cf,
                        }
                    )

        return factors


# ── Risk-archetype labels used by the demo ────────────────────────────────────
_ARCHETYPE_LABELS: dict[str, str] = {}


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import sys
    # Force UTF-8 on Windows console to avoid UnicodeEncodeError with cp1252
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    # ── Curated archetype demo — one offer per distinct risk driver ───────────
    # Each offer is handcrafted to isolate a specific expiration cause so the
    # demo exercises every tip and action-plan variant the system can produce.
    # The model and diagnosis engine determine which tips actually fire — no
    # hard-wiring here.

    _BASE: dict = dict(
        restaurant_avg_rating=4.0,
        restaurant_past_expired_rate=0.28,
        restaurant_offer_count=65,
        time_remaining_hours=2.0,
        sell_through_rate_realtime=0.0,   # snapshot: no orders yet
        day_of_week=3,
        visibility="IDENTIFIED",
        restaurant_id="DEMO-ARCH",
    )

    _archetypes: list[dict] = [
        # 1 — Dominant: stock (very high quantity, zero sell-through)
        dict(**_BASE, offer_id="ARCH-01-STOCK",
             discount_rate=38.0, quantity=35, time_to_pickup_hours=2.5,
             pickup_hour=20, description_length=110, category_sell_rate=0.50,
             view_count=12, engagement_rate=0.07, establishment_type="RESTAURANT"),

        # 2 — Dominant: visibility (nearly invisible offer, good category)
        dict(**_BASE, offer_id="ARCH-02-INVIS",
             discount_rate=46.0, quantity=10, time_to_pickup_hours=3.5,
             pickup_hour=13, description_length=90, category_sell_rate=0.65,
             view_count=2, engagement_rate=0.0, establishment_type="BAKERY"),

        # 3 — Dominant: pricing (17 % discount, very low for this offer)
        dict(**_BASE, offer_id="ARCH-03-PRICE",
             discount_rate=17.0, quantity=12, time_to_pickup_hours=3.0,
             pickup_hour=20, description_length=135, category_sell_rate=0.52,
             view_count=22, engagement_rate=0.11, establishment_type="RESTAURANT"),

        # 4 — Dominant: engagement (good views, CTR near zero)
        dict(**_BASE, offer_id="ARCH-04-ENGAGE",
             discount_rate=44.0, quantity=10, time_to_pickup_hours=3.5,
             pickup_hour=12, description_length=40, category_sell_rate=0.60,
             view_count=30, engagement_rate=0.008, establishment_type="FAST_FOOD"),

        # 5 — Dominant: timing (published only 30 min before pickup, very late)
        dict(**_BASE, offer_id="ARCH-05-TIMING",
             discount_rate=50.0, quantity=10, time_to_pickup_hours=0.5,
             pickup_hour=22, description_length=120, category_sell_rate=0.55,
             view_count=5, engagement_rate=0.04, establishment_type="RESTAURANT"),

        # 6 — Dominant: category (structural weak demand) + sales pace
        # Uses {**_BASE, ...} spread (not dict(**_BASE, ...)) to allow overriding
        # restaurant_past_expired_rate which already exists in _BASE.
        {**_BASE, "offer_id": "ARCH-06-CATEG",
         "discount_rate": 34.0, "quantity": 20, "time_to_pickup_hours": 2.5,
         "pickup_hour": 20, "description_length": 100, "category_sell_rate": 0.27,
         "view_count": 16, "engagement_rate": 0.06,
         "restaurant_past_expired_rate": 0.48, "establishment_type": "RESTAURANT"},

        # 7 — Dominant: content (description=15 chars, very low engagement)
        dict(**_BASE, offer_id="ARCH-07-CONTENT",
             discount_rate=45.0, quantity=10, time_to_pickup_hours=4.0,
             pickup_hour=13, description_length=15, category_sell_rate=0.65,
             view_count=14, engagement_rate=0.015, establishment_type="BAKERY"),

        # 8 — Compound: every lever is slightly wrong at the same time
        {**_BASE, "offer_id": "ARCH-08-CUMUL",
         "discount_rate": 21.0, "quantity": 28, "time_to_pickup_hours": 0.5,
         "pickup_hour": 22, "description_length": 20, "category_sell_rate": 0.30,
         "view_count": 4, "engagement_rate": 0.01,
         "restaurant_past_expired_rate": 0.58, "establishment_type": "RESTAURANT"},
    ]

    _archetype_labels: dict[str, str] = {
        "ARCH-01-STOCK":   "Stock excessif",
        "ARCH-02-INVIS":   "Faible visibilit\u00e9",
        "ARCH-03-PRICE":   "Remise insuffisante",
        "ARCH-04-ENGAGE":  "Faible engagement",
        "ARCH-05-TIMING":  "Mauvais timing",
        "ARCH-06-CATEG":   "Cat\u00e9gorie difficile",
        "ARCH-07-CONTENT": "Description insuffisante",
        "ARCH-08-CUMUL":   "Risque cumul\u00e9 (multi-facteurs)",
    }

    predictor = OfferRiskPredictor()
    demo_df = pd.DataFrame(_archetypes)
    results = predictor.predict(demo_df)

    sep = "-" * 72
    print(f"\n{sep}")
    print("  Archetype Risk Demo -- couverture de tous les types de risque")
    print(sep)

    for _, row in results.iterrows():
        oid      = row["offer_id"]
        label    = _archetype_labels.get(oid, oid)
        score    = row["risk_score"]
        level    = row["risk_level"]
        diag_out = row.get("diagnosis")

        _icon = {"HIGH": "[HIGH]", "MEDIUM": "[MED] ", "LOW": "[LOW] "}.get(level, "[?]  ")
        print(f"\n  {_icon} {oid}  [{label}]")
        print(f"    score={score:.3f}  level={level}")

        if diag_out and diag_out.get("summary"):
            print(f"    >> Diagnostic: {diag_out['summary']}")
            _axes_str = "  ".join(
                f"{a['label']} {int(round(a['share']*100))}%"
                for a in diag_out.get("axes", [])
            )
            if _axes_str:
                print(f"       Axes: {_axes_str}")

        for f in row["top_factors"]:
            print(
                f"    [!]  {f['feature']:<35s}"
                f"val={f['value']}  SHAP=+{f['shap_contribution']:.4f}"
            )
            cf = f.get("counterfactual")
            if cf and isinstance(cf, dict) and "message" in cf:
                print(f"      -> {cf['message']}")

        if row.get("action_plan"):
            ap = row["action_plan"]
            print(f"    [*] {ap['message']}")
            # Show up to 2 alternative plans
            for alt in ap.get("alternatives", []):
                print(f"        + {alt['label']}: {alt['message']}")
            exploited = ap.get("interactions_exploited", [])
            if exploited:
                top_syn = exploited[0]
                print(
                    f"      Synergie: "
                    f"{top_syn['features'][0]} x {top_syn['features'][1]} "
                    f"(force {top_syn['synergy']:.3f})"
                )

    print(f"\n{sep}")
    counts = results["risk_level"].value_counts().to_dict()
    print(f"  Distribution: {counts}")
    print(sep)
