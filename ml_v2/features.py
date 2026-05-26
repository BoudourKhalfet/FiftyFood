"""
Feature engineering for the offer expiration risk model.
Single responsibility: raw offer DataFrame → CatBoost-ready feature matrix.

Both train.py and predictor.py import from here — one source of truth.
"""

import numpy as np
import pandas as pd

# ── Feature manifest ──────────────────────────────────────────────────────────
# Ordered exactly as they will appear in the feature matrix.
# Any change here must be reflected in saved artifacts (retrain required).

NUMERIC_FEATURES: list[str] = [
    # -- Static (known at offer creation) ------------------------------------
    "discount_rate",  # % off original price
    "quantity",  # total units in the offer
    "time_to_pickup_hours",  # how far ahead the offer was published
    "pickup_hour",  # hour of day for pickup (0–23)
    "day_of_week",  # 0 = Monday … 6 = Sunday
    "description_length",  # character count of the description
    "category_sell_rate",  # historical sell rate for this category (0–1)
    "restaurant_avg_rating",  # restaurant rating (2.5–5.0)
    "restaurant_past_expired_rate",  # smoothed expiration rate (EWM span=10 over past offers — recent history weighted more)
    "restaurant_offer_count",  # how many completed offers this restaurant has — signals
    # how reliable the history features are (cold-start guard)
    # -- Dynamic (observed at snapshot time, updated each hourly check) ------
    "sell_through_rate_realtime",  # orders_placed / quantity at snapshot time
    "time_remaining_hours",  # hours until pickup at snapshot time
    "view_count",  # log1p(view_count) — compresses heavy tail
    "engagement_rate",  # click_count / view_count at snapshot time (CTR)
]

CATEGORICAL_FEATURES: list[str] = [
    "establishment_type",  # BAKERY | CAFE | FAST_FOOD | RESTAURANT | FOOD_TRUCK | CATERING
    "visibility",  # IDENTIFIED (restaurant shown) | ANONYMOUS (identity hidden)
    # kept for prediction accuracy — blocked from tips in predictor.py
]

ALL_FEATURES: list[str] = NUMERIC_FEATURES + CATEGORICAL_FEATURES


# ─────────────────────────────────────────────────────────────────────────────
def build_features(
    df: pd.DataFrame,
) -> tuple[np.ndarray, np.ndarray | None, list[str], list[int]]:
    """
    Transform a raw offer DataFrame into a CatBoost-ready feature matrix.

    Parameters
    ----------
    df : DataFrame containing the raw schema columns.
         Must have 'view_count'. 'expired' column is optional (used for training).

    Returns
    -------
    X             : ndarray of shape (n_offers, n_features)
    y             : int ndarray of 0/1 labels, or None if 'expired' is absent
    feature_names : list[str] — ordered feature names matching X columns
    cat_indices   : list[int] — column indices of categorical features (for CatBoost Pool)
    """
    out = df.copy()

    # delivery_available removed — controlled by the platform, not the restaurant

    # log1p compression for view count — prevents a handful of viral offers
    # from dominating the feature scale
    out["view_count"] = np.log1p(out["view_count"].fillna(0))

    # Conservative fill for dynamic features: assume worst-case scenario
    # (no progress, no engagement) — safe default for cold offers
    for col in (
        "sell_through_rate_realtime",
        "engagement_rate",
        "time_remaining_hours",
    ):
        out[col] = out[col].fillna(0.0)

    # Explicit DataFrame annotation so Pylance doesn't widen to NDArray
    X: pd.DataFrame = out[ALL_FEATURES].copy()

    # CatBoost requires categorical columns to be string type
    for col in CATEGORICAL_FEATURES:
        X[col] = X[col].fillna("UNKNOWN").astype(str)

    cat_indices = [ALL_FEATURES.index(f) for f in CATEGORICAL_FEATURES]
    y = out["expired"].values.astype(int) if "expired" in out.columns else None

    return X.values, y, ALL_FEATURES, cat_indices
