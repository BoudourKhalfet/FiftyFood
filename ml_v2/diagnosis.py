"""
SHAP-driven risk diagnosis — replaces all static rule-based tip triggers.

Instead of hardcoded thresholds (e.g. "view_count < 15 → tip fires"),
this module groups positive SHAP contributions by semantic risk "axis"
(stock, visibility, pricing, engagement, timing, …) and computes each
axis's share of total expiration risk.

100 % model-derived — the CatBoost SHAP values are the sole source of truth.
No feature values are compared against fixed constants here.
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

# ── Risk axes ─────────────────────────────────────────────────────────────────
# Semantically related features are grouped into axes.
# Non-actionable features (establishment_type, visibility, restaurant_offer_count
# as a cold-start signal) are included so their SHAP is accounted for in the
# total — but their axes have lever=None, preventing tip generation.

_RISK_AXES: dict[str, list[str]] = {
    "stock":       ["quantity"],
    "visibility":  ["view_count"],
    "pricing":     ["discount_rate"],
    "engagement":  ["engagement_rate"],
    "timing":      ["time_to_pickup_hours", "pickup_hour"],
    "sales_pace":  ["sell_through_rate_realtime"],
    "content":     ["description_length"],
    "category":    ["category_sell_rate"],
    "reputation":  ["restaurant_past_expired_rate", "restaurant_avg_rating",
                    "restaurant_offer_count"],
    "day_demand":  ["day_of_week"],
}

_AXIS_LABELS_FR: dict[str, str] = {
    "stock":       "stock excessif",
    "visibility":  "faible visibilité",
    "pricing":     "remise insuffisante",
    "engagement":  "faible engagement",
    "timing":      "délai de publication court",
    "sales_pace":  "ventes lentes",
    "content":     "description insuffisante",
    "category":    "catégorie à faible demande",
    "reputation":  "historique d\u2019expiration",
    "day_demand":  "faible demande ce jour",
}

# Primary actionable lever for each axis (used by predictor to route tips)
AXIS_LEVER: dict[str, str | None] = {
    "stock":       "quantity",
    "visibility":  "content_quality",    # → photo + description
    "pricing":     "discount_rate",
    "engagement":  "content_quality",    # → title + photo
    "timing":      "time_to_pickup_hours",
    "sales_pace":  "discount_rate",      # best immediate lever
    "content":     "description_length",
    "category":    "discount_rate",      # compensate weak category with price
    "reputation":  None,                 # not actionable per-offer
    "day_demand":  "quantity",           # reduce qty on this day
}


# ── Data classes ──────────────────────────────────────────────────────────────

@dataclass
class RiskAxis:
    name: str
    label_fr: str
    shap_sum: float
    share: float                          # fraction of total positive SHAP (0–1)
    contributing_features: list[str] = field(default_factory=list)
    lever: str | None = None


@dataclass
class OfferDiagnosis:
    axes: list[RiskAxis]                  # sorted by share desc (all positive axes)
    primary: RiskAxis | None              # highest-share axis
    secondary: list[RiskAxis]            # axes with share >= min_secondary_share
    total_positive_shap: float

    # ── Convenience helpers ───────────────────────────────────────────────────

    @property
    def dominant_axes(self) -> list[RiskAxis]:
        """Axes with share >= 10 %, sorted by share desc."""
        return [a for a in self.axes if a.share >= 0.10]

    def axis_share(self, axis_name: str) -> float:
        """Return the share of a specific axis, 0.0 if absent."""
        for a in self.axes:
            if a.name == axis_name:
                return a.share
        return 0.0

    def is_primary(self, axis_name: str) -> bool:
        return self.primary is not None and self.primary.name == axis_name

    def has_axis(self, axis_name: str, min_share: float = 0.10) -> bool:
        return self.axis_share(axis_name) >= min_share


# ── Core function ─────────────────────────────────────────────────────────────

def diagnose(
    shap_row: np.ndarray,
    feat_names: list[str],
    min_secondary_share: float = 0.15,
) -> OfferDiagnosis:
    """
    Pure SHAP-driven offer diagnosis — zero hardcoded feature thresholds.

    Groups positive SHAP contributions by semantic axis and computes each
    axis's share of total expiration risk. The CatBoost model has already
    encoded all feature relationships; this function simply reads the output.

    Parameters
    ----------
    shap_row             : SHAP values for one offer (shape: n_features).
                           Negative values (features helping the offer) are ignored.
    feat_names           : Feature names aligned with shap_row indices.
    min_secondary_share  : Minimum share for an axis to appear as "secondary"
                           (default 15 % — axes below this are still in .axes
                           but won't be listed as secondary for message generation).

    Returns
    -------
    OfferDiagnosis — fully model-derived, no static rules.
    """
    risk_shap = np.where(shap_row > 0.0, shap_row, 0.0)
    total = float(risk_shap.sum())

    if total <= 1e-9:
        return OfferDiagnosis(
            axes=[], primary=None, secondary=[], total_positive_shap=0.0
        )

    feat_idx: dict[str, int] = {f: i for i, f in enumerate(feat_names)}
    axes: list[RiskAxis] = []

    for axis_name, axis_feats in _RISK_AXES.items():
        axis_shap = 0.0
        contributing: list[str] = []
        for f in axis_feats:
            if f in feat_idx:
                v = float(risk_shap[feat_idx[f]])
                if v > 0:
                    axis_shap += v
                    contributing.append(f)
        if axis_shap <= 0:
            continue
        axes.append(
            RiskAxis(
                name=axis_name,
                label_fr=_AXIS_LABELS_FR[axis_name],
                shap_sum=round(axis_shap, 4),
                share=round(axis_shap / total, 4),
                contributing_features=contributing,
                lever=AXIS_LEVER.get(axis_name),
            )
        )

    axes.sort(key=lambda a: a.share, reverse=True)
    primary = axes[0] if axes else None
    secondary = [a for a in axes[1:] if a.share >= min_secondary_share]

    return OfferDiagnosis(
        axes=axes,
        primary=primary,
        secondary=secondary,
        total_positive_shap=round(total, 4),
    )


def diagnosis_summary(diag: OfferDiagnosis) -> str:
    """
    One-line French summary of the risk diagnosis.
    Used in action plans, advisor tips, and the demo display.
    """
    if not diag.axes:
        return "Aucun facteur de risque dominant."

    dominant = diag.dominant_axes or ([diag.primary] if diag.primary else [])
    if not dominant:
        return "Risque diffus — aucun facteur ne domine."

    if len(dominant) == 1:
        a = dominant[0]
        return f"{a.label_fr.capitalize()} ({int(round(a.share * 100))}\u202f% du risque)."
    elif len(dominant) == 2:
        a, b = dominant
        return (
            f"{a.label_fr.capitalize()} ({int(round(a.share * 100))}\u202f%) "
            f"et {b.label_fr} ({int(round(b.share * 100))}\u202f%)."
        )
    else:
        parts = [
            f"{a.label_fr} ({int(round(a.share * 100))}\u202f%)"
            for a in dominant[:3]
        ]
        return "Risque cumul\u00e9\u202f: " + ", ".join(parts) + "."
