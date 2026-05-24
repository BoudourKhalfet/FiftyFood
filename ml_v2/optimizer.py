"""
Multi-Feature Counterfactual Optimizer for ML v2.

Explores combinations of actionable features to find the optimal action plan.
Returns a PRIMARY plan (best risk/cost balance) plus up to 2 ALTERNATIVES
(minimal intervention, aggressive intervention) so the restaurant can choose.

Key design decisions vs v1:
  - quantity is NOT an optimizable lever here. The restaurant cannot unsell
    food that already exists as surplus -- advising a quantity cut means
    discarding food, which is the opposite of the platform mission.
    Quantity guidance is provided separately via _qty_advice_for_day
    (scoped "next_time", based on historical patterns per day/estab).
  - Actionable levers for an active offer: discount_rate (NOW),
    description_length (NOW if editing is allowed), time_to_pickup_hours
    (NEXT_TIME -- can't change pickup for an active offer).
  - discount grid: 4 levels (+5, +10, +15, +20) for finer-grained suggestions.
  - Multi-plan output: plan A (minimal change), plan B (optimal ratio),
    plan C (aggressive); deduplication ensures they are genuinely different.
  - SHAP interaction note: appended to primary message when a strong
    detected interaction (synergy >= 0.12) involves a changed feature.
"""

import itertools

import numpy as np
from catboost import Pool

_DISCOUNT_CAP = 62.0
_MIN_REDUCTION = 0.05   # minimum risk reduction (5 pts) to show any plan


# French labels for actionable features (used in synergy notes and messages)
_FEAT_FR: dict[str, str] = {
    "quantity":                  "quantite",
    "discount_rate":             "remise",
    "description_length":        "description",
    "time_to_pickup_hours":      "delai de publication",
    "view_count":                "vues",
    "sell_through_rate_realtime": "taux de vente",
    "engagement_rate":           "engagement",
}


# ── Message builder ───────────────────────────────────────────────────────────

def _build_plan_message(
    changes: list[dict],
    current_score: float,
    plan_score: float,
    interacting_pairs: list[tuple],
    plan_type: str = "optimal",
) -> str:
    """
    Build a context-aware French message for one action plan.

    plan_type controls the urgency prefix:
      "optimal"    -> standard urgency based on current_score
      "minimal"    -> "Option legere"
      "aggressive" -> "Option maximale"
    """
    reduction_pts = int(round((current_score - plan_score) * 100))
    risk_curr = int(round(current_score * 100))
    risk_new = int(round(plan_score * 100))
    changed_features = {c["feature"] for c in changes}

    qty_ch  = next((c for c in changes if c["feature"] == "quantity"), None)
    disc_ch = next((c for c in changes if c["feature"] == "discount_rate"), None)
    desc_ch = next((c for c in changes if c["feature"] == "description_length"), None)
    ttp_ch  = next((c for c in changes if c["feature"] == "time_to_pickup_hours"), None)

    # Urgency prefix
    if plan_type == "minimal":
        prefix = "Option legere"
    elif plan_type == "aggressive":
        prefix = "Option maximale"
    elif current_score >= 0.90:
        prefix = "Situation critique"
    elif current_score >= 0.75:
        prefix = "Risque eleve"
    else:
        prefix = "Recommandation"

    # Context-specific body based on which features change.
    # Note: quantity is never in changed_features (excluded from optimizer).
    if changed_features == {"discount_rate"} and disc_ch:
        _do = int(round(disc_ch["current"]))
        _ds = int(round(disc_ch["suggested"]))
        body = (
            f"passer de {_do}% a {_ds}% de remise devrait declencher les commandes. "
            f"Risque: {risk_curr}% -> {risk_new}%. (-{reduction_pts} pts)"
        )

    elif changed_features == {"description_length"} and desc_ch:
        _dss = int(round(desc_ch["suggested"]))
        body = (
            f"enrichir la description ({_dss}+ car.) pour augmenter les clics. "
            f"Risque: {risk_curr}% -> {risk_new}%. (-{reduction_pts} pts)"
        )

    elif changed_features == {"time_to_pickup_hours"} and ttp_ch:
        _ts = round(ttp_ch["suggested"], 1)
        body = (
            f"publier {_ts}h avant le pickup (plus de visibilite). "
            f"Risque: {risk_curr}% -> {risk_new}%. (-{reduction_pts} pts)"
        )

    elif "discount_rate" in changed_features and "description_length" in changed_features and disc_ch and desc_ch:
        _ds  = int(round(disc_ch["suggested"]))
        _dss = int(round(desc_ch["suggested"]))
        body = (
            f"passer a {_ds}% de remise et enrichir la description ({_dss}+ car.). "
            f"Risque: {risk_curr}% -> {risk_new}%. (-{reduction_pts} pts)"
        )

    else:
        # Generic fallback for multi-feature combos not explicitly handled
        parts = []
        for c in changes:
            f, s = c["feature"], c["suggested"]
            if f == "discount_rate":
                parts.append(f"passez a {int(round(s))}% de remise")
            elif f == "description_length":
                parts.append(f"description {int(round(s))}+ car.")
            elif f == "time_to_pickup_hours":
                parts.append(f"publiez {round(s, 1)}h avant le pickup")
            elif f == "quantity":
                parts.append(f"reduisez a {int(round(s))} unites")
        body = " + ".join(parts) + f". Risque: {risk_curr}% -> {risk_new}%. (-{reduction_pts} pts)"

    # SHAP interaction note (primary plan only — keeps alternatives concise)
    synergy_note = ""
    if plan_type == "optimal":
        for f1, f2, strength in interacting_pairs:
            if strength < 0.12:
                break  # list is sorted desc
            if f1 in changed_features or f2 in changed_features:
                _lf1 = _FEAT_FR.get(f1, f1)
                _lf2 = _FEAT_FR.get(f2, f2)
                synergy_note = (
                    f" [{_lf1} x {_lf2} interagissent -- "
                    f"agir sur les deux a un effet superieur a la somme.]"
                )
                break

    return f"{prefix}: {body}{synergy_note}"


# ── Two-plan dedup helper ─────────────────────────────────────────────────────

def _plans_differ(p1: dict, p2: dict) -> bool:
    """True when two plans modify different feature sets or have notably different scores."""
    f1 = {c["feature"] for c in p1["changes"]}
    f2 = {c["feature"] for c in p2["changes"]}
    if f1 != f2:
        return True
    # Same feature set — differ only if final risk is meaningfully different
    return abs(p1["score"] - p2["score"]) > 0.05


# ── Main entry point ──────────────────────────────────────────────────────────

def optimize_offer(
    predictor,
    X_row: np.ndarray,
    current_score: float,
    top_shap_features: list[str],
    interacting_pairs: list[tuple],
    estab_type: str,
    feature_names: list[str],
    current_values: dict[str, float],
    estab_bounds: dict[str, dict[str, float]],
    target_risk: float = 0.35,
) -> dict | None:
    """
    Find the optimal multi-feature action plan and up to 2 alternatives.

    Grid bounds for quantity are capped at a max 30 % reduction
    (never below max(p10_sold, 70 % of current, 5 units)) so the optimizer
    does not trivially dominate by suggesting an extreme stock cut every time.

    Returns
    -------
    dict with keys:
      current_risk, optimized_risk, total_reduction, changes, message,
      alternatives (list of {type, label, optimized_risk, reduction_pts,
                              changes, message}),
      interactions_exploited, advice_type
    """
    # quantity is intentionally excluded: the restaurant cannot reduce
    # food that already exists as surplus. Only these 3 levers are actionable
    # on an active offer (discount NOW, description NOW, TTP next time).
    actionable = {"discount_rate", "description_length", "time_to_pickup_hours"}

    # ── 1. Build search grid ────────────────────────────────────────────
    grid: dict[str, list[float]] = {}
    for feat in actionable:
        curr   = current_values.get(feat, 0.0)
        bounds = estab_bounds.get(feat, {})

        candidates: list[float] = [curr]  # baseline (no change)

        if feat == "discount_rate":
            # 4 increment levels for fine-grained discount advice
            for delta in [5.0, 10.0, 15.0, 20.0]:
                new_val = min(curr + delta, _DISCOUNT_CAP)
                if new_val > curr + 0.5:
                    candidates.append(new_val)

        elif feat == "description_length":
            # Two levels of description improvement
            for add in [30.0, 80.0]:
                candidates.append(curr + add)

        elif feat == "time_to_pickup_hours":
            # Two levels of earlier publication (next_time lever)
            for add in [1.0, 2.0]:
                candidates.append(curr + add)

        grid[feat] = list(set(candidates))

    # ── 2. Generate combinations ──────────────────────────────────────────────
    keys        = list(grid.keys())
    value_lists = [grid[k] for k in keys]
    combinations = list(itertools.product(*value_lists))

    # Cap to avoid very long inference times (4 features x ~5 values = 625 max)
    if len(combinations) > 250:
        combinations = combinations[:250]
    if len(combinations) <= 1:
        return None

    # ── 3. Batch inference ────────────────────────────────────────────────────
    cf_matrix = np.tile(X_row, (len(combinations), 1))
    for i, combo in enumerate(combinations):
        for k, feat_name in enumerate(keys):
            idx = feature_names.index(feat_name)
            cf_matrix[i, idx] = combo[k]

    pool      = Pool(cf_matrix, cat_features=predictor._cat_idx)
    raw       = predictor._model.predict_proba(pool)[:, 1]
    calibrated = np.clip(predictor._calibrator.predict(raw), 0.0, 1.0)

    # ── 4. Build valid plan list ──────────────────────────────────────────────
    valid_plans: list[dict] = []
    for i, combo in enumerate(combinations):
        score   = float(calibrated[i])
        changes = []
        cost    = 0.0

        for k, feat_name in enumerate(keys):
            val  = combo[k]
            orig = current_values.get(feat_name, 0.0)
            if abs(val - orig) > 0.01:
                changes.append({
                    "feature":  feat_name,
                    "current":  orig,
                    "suggested": val,
                    "scope": "now" if feat_name in ("discount_rate", "description_length")
                             else "next_time",
                })
                # Cost function: penalise intrusive actions
                if feat_name == "discount_rate":
                    cost += ((val - orig) / 25.0) * 1.0
                elif feat_name == "description_length":
                    cost += 0.1
                elif feat_name == "time_to_pickup_hours":
                    cost += 0.2

        if not changes:
            continue

        valid_plans.append({
            "score":     score,
            "reduction": current_score - score,
            "changes":   changes,
            "cost":      cost,
        })

    if not valid_plans:
        return None

    # ── 5. Select three plan archetypes ──────────────────────────────────────
    # Only consider plans with at least MIN_REDUCTION improvement
    meaningful = [p for p in valid_plans if p["reduction"] >= _MIN_REDUCTION]
    if not meaningful:
        return None

    # Plan B (primary / optimal): best risk-reduction / cost ratio
    plan_b = max(meaningful, key=lambda p: p["reduction"] / max(p["cost"], 0.01))

    # Plan A (minimal): fewest levers pulled, smallest cost, still >= MIN_REDUCTION
    plan_a = min(meaningful, key=lambda p: (len(p["changes"]), p["cost"]))

    # Plan C (aggressive): absolute maximum risk reduction (may exceed target)
    plan_c = min(valid_plans, key=lambda p: p["score"])

    # Primary is plan B
    primary = plan_b

    # ── 6. Build alternatives (deduplicated) ──────────────────────────────────
    alternatives: list[dict] = []
    for plan_type, plan, label in [
        ("minimal",    plan_a, "Option legere"),
        ("aggressive", plan_c, "Option maximale"),
    ]:
        if (
            plan is not primary
            and _plans_differ(plan, primary)
            and plan["reduction"] >= _MIN_REDUCTION
        ):
            alt_msg = _build_plan_message(
                plan["changes"], current_score, plan["score"],
                interacting_pairs, plan_type=plan_type,
            )
            alternatives.append({
                "type":           plan_type,
                "label":          label,
                "optimized_risk": round(plan["score"], 4),
                "reduction_pts":  int(round(plan["reduction"] * 100)),
                "changes":        plan["changes"],
                "message":        alt_msg,
            })

    # ── 7. Build primary message ──────────────────────────────────────────────
    primary_message = _build_plan_message(
        primary["changes"], current_score, primary["score"],
        interacting_pairs, plan_type="optimal",
    )

    return {
        "current_risk":    round(current_score, 4),
        "optimized_risk":  round(primary["score"], 4),
        "total_reduction": round(primary["reduction"], 4),
        "changes":         primary["changes"],
        "message":         primary_message,
        "alternatives":    alternatives,
        "interactions_exploited": [
            {"features": [f1, f2], "synergy": round(strength, 4)}
            for f1, f2, strength in interacting_pairs[:2]
        ],
        "advice_type": "combined_optimal_plan",
    }
