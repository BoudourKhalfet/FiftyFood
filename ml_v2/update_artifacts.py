"""
Patch artifacts.pkl to add qty_advice_by_day lookup table.

Run this instead of the full train.py when catboost is not installed or
when you only want to update the lookup tables without retraining the model.

Requirements: pandas, numpy, joblib, scikit-learn  (no catboost needed)

Usage:
    python update_artifacts.py
"""

import os
import sys
import logging

import joblib
import numpy as np
import pandas as pd

logging.basicConfig(level=logging.INFO, format="%(levelname)s  %(message)s")
logger = logging.getLogger(__name__)

# ── Paths (same as train.py / predictor.py) ───────────────────────────────────
MODEL_DIR = "models"
ARTIF_PATH = os.path.join(MODEL_DIR, "artifacts.pkl")
CSV_PATH = "offer_history.csv"

# ── Thresholds (must match predictor.py / train.py constants) ───────────────────
_DAY_EXPIRED_RATE_THRESHOLD: float = 0.40
_DAY_MIN_SAMPLES: int = 20   # matches _MIN_GROUP_SAMPLES in train.py
_MIN_GROUP_SAMPLES: int = 20  # used by best_hours_by_estab — same floor

# ── Training split ratio (must match train.py) ────────────────────────────────
# We only use the first 70 % (training portion) to compute the lookup tables.
# Using the full dataset would leak calibration / test signals into the tips.
_TRAIN_RATIO: float = 0.70


# ─────────────────────────────────────────────────────────────────────────────
def compute_qty_advice_by_day(df: pd.DataFrame) -> dict[str, dict[int, dict]]:
    """
    Compute qty_advice_by_day from a sorted offer history DataFrame.

    For each (establishment_type, day_of_week) bucket:
      - expired_rate  : fraction of offers that expired on this day
      - suggested_qty : median quantity of SOLD offers on this day
                        → the qty level at which demand actually cleared
      - n_total       : sample count (used as confidence guard)

    Rationale: restaurants sell surplus, they cannot schedule WHEN it appears.
    But they CAN choose HOW MUCH to post. A high expired_rate on a given day
    means the quantity posted routinely exceeds that day's demand.
    """
    n_train = int(len(df) * _TRAIN_RATIO)
    train_df = df.iloc[:n_train]

    # ── All-offer stats per (estab, day) ─────────────────────────────────────
    all_day = (
        train_df.groupby(["establishment_type", "day_of_week"])
        .agg(
            expired_rate=("expired", "mean"),
            n_total=("expired", "count"),
        )
        .reset_index()
    )

    # ── Median quantity of SOLD offers per (estab, day) ───────────────────────
    sold_day = (
        train_df[train_df["expired"] == 0]
        .groupby(["establishment_type", "day_of_week"])
        .agg(suggested_qty=("quantity", "median"))
        .reset_index()
    )

    merged = all_day.merge(
        sold_day, on=["establishment_type", "day_of_week"], how="left"
    )

    # Fallback: days with no sold offers → use overall median qty for that estab
    estab_median = train_df.groupby("establishment_type")["quantity"].median()
    for idx, row in merged.iterrows():
        if pd.isna(row["suggested_qty"]):
            merged.at[idx, "suggested_qty"] = float(
                estab_median.get(row["establishment_type"], 10.0)
            )

    # ── Build nested dict ─────────────────────────────────────────────────────
    result: dict[str, dict[int, dict]] = {}
    for _, row in merged.iterrows():
        estab = str(row["establishment_type"])
        dow = int(row["day_of_week"])
        result.setdefault(estab, {})[dow] = {
            "expired_rate": round(float(row["expired_rate"]), 4),
            "suggested_qty": round(float(row["suggested_qty"]), 1),
            "n_total": int(row["n_total"]),
        }
    return result


# ─────────────────────────────────────────────────────────────────────────────
def compute_best_hours_by_estab(df: pd.DataFrame) -> dict[str, list[int]]:
    """
    Compute hours ranked by sell rate per establishment type.
    Mirrors train.py section 9b — only hours with n >= _MIN_GROUP_SAMPLES.

    Used by predictor._best_hour_cf() to suggest a feasible pickup hour.
    Without this, the predictor falls back to the universal hardcoded list
    [12, 13, 19, 20, 9, 11] for ALL establishment types.
    """
    n_train = int(len(df) * _TRAIN_RATIO)
    train_df = df.iloc[:n_train]

    hour_stats = (
        train_df.groupby(["establishment_type", "pickup_hour"])
        .agg(sell_rate=("expired", lambda x: 1.0 - x.mean()), n=("expired", "count"))
        .reset_index()
    )
    hour_stats = hour_stats[hour_stats["n"] >= _MIN_GROUP_SAMPLES]

    result: dict[str, list[int]] = {}
    for estab, grp in hour_stats.groupby("establishment_type"):
        ranked = grp.sort_values("sell_rate", ascending=False)["pickup_hour"].tolist()
        result[str(estab)] = [int(h) for h in ranked]
    return result


# ─────────────────────────────────────────────────────────────────────────────
def compute_qty_advice_by_restaurant_day(df: pd.DataFrame) -> dict[str, dict[int, dict]]:
    """
    Compute per-restaurant per-day quantity advice from a sorted offer history DataFrame.

    More personalized than the estab-type version. Only reliable for restaurants
    with enough offers on a given day (n_total >= _DAY_MIN_SAMPLES).

    predictor._qty_advice_for_day() consults this first and falls back to the
    estab-type lookup when data is absent or too sparse.
    """
    n_train = int(len(df) * _TRAIN_RATIO)
    train_df = df.iloc[:n_train]

    # Estab-type median quantity — used as fallback for days with no sold offers
    estab_median = train_df.groupby("establishment_type")["quantity"].median()
    rest_estab_map = (
        train_df[["restaurant_id", "establishment_type"]]
        .drop_duplicates("restaurant_id")
        .set_index("restaurant_id")["establishment_type"]
    )

    all_rest_day = train_df.groupby(["restaurant_id", "day_of_week"]).agg(
        expired_rate=("expired", "mean"),
        n_total=("expired", "count"),
    ).reset_index()

    sold_rest_day = (
        train_df[train_df["expired"] == 0]
        .groupby(["restaurant_id", "day_of_week"])
        .agg(suggested_qty=("quantity", "median"))
        .reset_index()
    )

    merged = all_rest_day.merge(
        sold_rest_day, on=["restaurant_id", "day_of_week"], how="left"
    )

    for idx, row in merged.iterrows():
        if pd.isna(row["suggested_qty"]):
            estab = str(rest_estab_map.get(row["restaurant_id"], "UNKNOWN"))
            merged.at[idx, "suggested_qty"] = float(estab_median.get(estab, 10.0))

    result: dict[str, dict[int, dict]] = {}
    for _, row in merged.iterrows():
        rid = str(row["restaurant_id"])
        dow = int(row["day_of_week"])
        result.setdefault(rid, {})[dow] = {
            "expired_rate": round(float(row["expired_rate"]), 4),
            "suggested_qty": round(float(row["suggested_qty"]), 1),
            "n_total": int(row["n_total"]),
        }
    return result


# ─────────────────────────────────────────────────────────────────────────────
def main() -> None:
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    # ── 1. Load offer history ─────────────────────────────────────────────────
    if not os.path.exists(CSV_PATH):
        logger.error("'%s' not found. Run generator.py first.", CSV_PATH)
        sys.exit(1)

    df = pd.read_csv(CSV_PATH, parse_dates=["created_at"])
    df = df.sort_values("created_at").reset_index(drop=True)
    logger.info("Loaded %d offers from %s", len(df), CSV_PATH)

    # ── 2. Compute new lookup table ───────────────────────────────────────────
    qty_advice = compute_qty_advice_by_day(df)

    n_buckets = sum(len(v) for v in qty_advice.values())
    n_actionable = sum(
        1
        for estab_data in qty_advice.values()
        for stats in estab_data.values()
        if stats["expired_rate"] >= _DAY_EXPIRED_RATE_THRESHOLD
        and stats["n_total"] >= _DAY_MIN_SAMPLES
    )
    logger.info(
        "qty_advice_by_day: %d buckets  |  %d actionable (>= %.0f%% expired rate, n >= %d)",
        n_buckets,
        n_actionable,
        _DAY_EXPIRED_RATE_THRESHOLD * 100,
        _DAY_MIN_SAMPLES,
    )

    logger.info("Actionable quantity tips by day (estab-level, n >= %d):", _DAY_MIN_SAMPLES)
    for estab in sorted(qty_advice.keys()):
        for dow in sorted(qty_advice[estab].keys()):
            stats = qty_advice[estab][dow]
            if (
                stats["expired_rate"] >= _DAY_EXPIRED_RATE_THRESHOLD
                and stats["n_total"] >= _DAY_MIN_SAMPLES
            ):
                logger.info(
                    "  %-14s  %s  expired=%.0f%%  suggest_qty=%.0f  n=%d",
                    estab,
                    day_names[dow],
                    stats["expired_rate"] * 100,
                    stats["suggested_qty"],
                    stats["n_total"],
                )

    # ── 2b. Compute per-restaurant per-day lookup ─────────────────────────────
    qty_rest_advice = compute_qty_advice_by_restaurant_day(df)

    # ── 2c. Compute best hours per establishment type ─────────────────────────
    best_hours = compute_best_hours_by_estab(df)
    logger.info(
        "best_hours_by_estab: %d establishment types covered",
        len(best_hours),
    )
    for estab in sorted(best_hours.keys()):
        logger.info("  %-14s  top hours: %s", estab, best_hours[estab][:4])
    n_rest_buckets = sum(len(v) for v in qty_rest_advice.values())
    n_rest_actionable = sum(
        1
        for rid_data in qty_rest_advice.values()
        for stats in rid_data.values()
        if stats["expired_rate"] >= _DAY_EXPIRED_RATE_THRESHOLD
        and stats["n_total"] >= _DAY_MIN_SAMPLES
    )
    logger.info(
        "qty_advice_by_restaurant_day: %d restaurant-day buckets  |  %d actionable",
        n_rest_buckets,
        n_rest_actionable,
    )

    # ── 3. Load existing artifacts ────────────────────────────────────────────
    if not os.path.exists(ARTIF_PATH):
        logger.error("'%s' not found. Run train.py first.", ARTIF_PATH)
        sys.exit(1)

    try:
        artifacts = joblib.load(ARTIF_PATH)
    except Exception as exc:
        logger.error(
            "Could not load '%s': %s\n"
            "This usually means the artifacts were saved with a module "
            "(e.g. _PlattCalibrator) that cannot be found without catboost.\n"
            "Install catboost and run `python train.py` instead.",
            ARTIF_PATH,
            exc,
        )
        sys.exit(1)

    # ── 4. Inject new key and save ────────────────────────────────────────────
    already_present = "qty_advice_by_day" in artifacts
    artifacts["qty_advice_by_day"] = qty_advice
    artifacts["qty_advice_by_restaurant_day"] = qty_rest_advice
    artifacts["best_hours_by_estab"] = best_hours
    joblib.dump(artifacts, ARTIF_PATH)

    action = "UPDATED" if already_present else "ADDED"
    logger.info("artifacts.pkl — qty_advice_by_day %s         →  %s", action, ARTIF_PATH)
    logger.info("artifacts.pkl — qty_advice_by_restaurant_day %s  →  %s", action, ARTIF_PATH)
    logger.info("Done. Predictor will use the new quantity-by-day tips on next load.")


if __name__ == "__main__":
    main()
