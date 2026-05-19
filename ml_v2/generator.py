"""
Synthetic offer data generator — FiftyFood expiration risk model.
Mirrors schema.prisma columns exactly so training data maps 1-to-1 to real DB queries.

Run once:
    python generator.py   →   offer_history.csv
"""

import os
from datetime import timedelta

import numpy as np
import pandas as pd

# ── Category base sell-through rates (calibrated to food-rescue dynamics) ─────
# Lower than typical e-commerce: surplus food has limited demand windows.
CATEGORY_SELL_RATES: dict[str, float] = {
    "BAKERY": 0.65,
    "FAST_FOOD": 0.60,
    "DESSERT": 0.60,
    "CAFE": 0.57,
    "BREAKFAST": 0.55,
    "SANDWICH": 0.54,
    "BURGER": 0.53,
    "BRUNCH": 0.51,
    "SALAD": 0.50,
    "PIZZA": 0.49,
    "STREET_FOOD": 0.51,
    "HEALTHY": 0.48,
    "VEGETARIAN": 0.46,
    "GRILL": 0.45,
    "PASTA": 0.42,
    "BBQ": 0.44,
    "SUSHI": 0.41,
    "SEAFOOD": 0.37,
    "FINE_DINING": 0.30,
}

# ── Establishment type → realistic category menu ───────────────────────────────
ESTAB_CATEGORIES: dict[str, list[str]] = {
    "BAKERY": ["BAKERY", "BREAKFAST", "DESSERT"],
    "CAFE": ["CAFE", "BREAKFAST", "BRUNCH", "DESSERT", "SANDWICH"],
    "FAST_FOOD": ["FAST_FOOD", "BURGER", "PIZZA", "SANDWICH", "STREET_FOOD"],
    "RESTAURANT": [
        "GRILL",
        "PASTA",
        "FINE_DINING",
        "HEALTHY",
        "SALAD",
        "SEAFOOD",
        "SUSHI",
        "VEGETARIAN",
    ],
    "FOOD_TRUCK": ["STREET_FOOD", "BURGER", "BBQ", "SANDWICH", "FAST_FOOD"],
    "CATERING": ["FINE_DINING", "GRILL", "PASTA", "HEALTHY"],
}

# ── Hourly demand multipliers (relative to baseline = 1.0) ────────────────────
_HOUR_DEMAND: dict[int, float] = {h: 1.0 for h in range(24)}
_HOUR_DEMAND.update(
    {
        7: 1.12,
        8: 1.15,
        9: 1.10,  # breakfast rush
        11: 1.18,
        12: 1.22,
        13: 1.20,
        14: 1.12,  # lunch rush
        18: 1.10,
        19: 1.18,
        20: 1.20,
        21: 1.12,  # dinner rush
        22: 0.65,
        23: 0.50,  # late night — low demand
    }
)

# ── Day-of-week demand multipliers ────────────────────────────────────────────
_DOW_DEMAND: dict[int, float] = {
    0: 1.00,
    1: 1.00,
    2: 1.02,
    3: 1.04,
    4: 1.10,
    5: 1.22,
    6: 1.18,  # Fri–Sun boost
}


# ─────────────────────────────────────────────────────────────────────────────
def _sell_probability(offer: dict) -> float:
    """
    Compute P(sold) from static offer features.
    All effects are additive on the probability, then clipped to [0.05, 0.97].
    This mirrors the real business levers restaurants can pull.
    """
    p = offer["category_sell_rate"]

    # Discount incentive — non-linear: sweet spot is 40-60 %
    dr = offer["discount_rate"]
    if dr < 20:
        p -= 0.20
    elif dr < 30:
        p -= 0.09
    elif dr < 40:
        p += 0.00
    elif dr < 50:
        p += 0.07
    elif dr < 60:
        p += 0.13
    else:
        p += 0.18

    # Quantity penalty — more units require broader demand to clear
    p -= max(0.0, (offer["quantity"] - 10)) * 0.013

    # Lead time — posting too late leaves no exposure window
    ttp = offer["time_to_pickup_hours"]
    if ttp < 1:
        p -= 0.20
    elif ttp < 2:
        p -= 0.08
    elif ttp <= 4:
        p += 0.00
    elif ttp <= 6:
        p += 0.06
    else:
        p += 0.10

    # Time-of-day and day-of-week demand signals
    p += (_HOUR_DEMAND.get(offer["pickup_hour"], 1.0) - 1.0) * 0.50
    p += (_DOW_DEMAND[offer["day_of_week"]] - 1.0) * 0.40

    # Offer configuration levers
    # delivery_available removed — platform-controlled, not a restaurant lever
    if offer["visibility"] == "ANONYMOUS":
        p += 0.07  # reaches non-registered users
    # has_photo removed — photo upload is mandatory on the platform, always present

    # Description quality proxy
    dl = offer["description_length"]
    if dl < 30:
        p -= 0.05
    elif dl > 100:
        p += 0.04

    # Restaurant reputation signals
    p += (offer["restaurant_avg_rating"] - 3.5) * 0.06
    p -= offer["restaurant_past_expired_rate"] * 0.14  # track record matters

    return float(np.clip(p, 0.05, 0.97))


# ─────────────────────────────────────────────────────────────────────────────
def generate_restaurants(n: int = 80, seed: int = 42) -> pd.DataFrame:
    """
    Generate a pool of restaurants with varying profiles.
    Each restaurant has an experience tier that sets its inherent expired-rate prior.
    """
    rng = np.random.default_rng(seed)
    cities = ["Tunis", "Sfax", "Sousse", "Monastir", "Bizerte", "Nabeul"]
    rows = []
    for i in range(n):
        estab = rng.choice(list(ESTAB_CATEGORIES.keys()))
        tier = rng.choice(["new", "mid", "veteran"], p=[0.25, 0.50, 0.25])
        # New restaurants expire more — they haven't learned the platform yet
        base_er = {"new": 0.46, "mid": 0.31, "veteran": 0.18}[tier]
        rows.append(
            {
                "restaurant_id": f"R{i + 1:03d}",
                "establishment_type": estab,
                "city": rng.choice(cities),
                "avg_rating": float(np.clip(rng.normal(3.8, 0.55), 2.5, 5.0)),
                "_base_expired_rate": float(
                    np.clip(base_er + rng.uniform(-0.05, 0.05), 0.05, 0.70)
                ),
            }
        )
    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────────
def generate_offers(
    restaurants: pd.DataFrame,
    n_offers: int = 1200,
    seed: int = 42,
) -> pd.DataFrame:
    """
    Generate a chronologically ordered offer dataset.

    Dynamic features (sell_through_rate_realtime, view_count, engagement_rate)
    are simulated at snapshot time = 2 hours before pickup, which is when
    the hourly risk checker would observe them on active offers.

    Leakage guards:
      - restaurant_past_expired_rate uses an expanding window (only past offers).
      - category_sell_rate has added noise to simulate real estimation uncertainty.
      - Dynamic features are noisy enough that they cannot perfectly reveal the label.
    """
    rng = np.random.default_rng(seed)
    start_date = pd.Timestamp("2024-01-01")

    # Per-restaurant expanding outcome history — prevents temporal leakage
    hist: dict[str, list[int]] = {r: [] for r in restaurants["restaurant_id"]}

    records: list[dict] = []

    for i in range(n_offers):
        rest = restaurants.sample(1, random_state=int(rng.integers(0, 99_999))).iloc[0]
        rid = rest["restaurant_id"]
        estab = rest["establishment_type"]

        # Category and its sell rate (with estimation noise for realism)
        category = rng.choice(ESTAB_CATEGORIES[estab])
        cat_sell_rate = float(
            np.clip(CATEGORY_SELL_RATES[category] + rng.normal(0.0, 0.04), 0.15, 0.90)
        )

        # Pickup hour — biased by category type (matches real food-service timing)
        if category in ("BREAKFAST", "CAFE", "BRUNCH"):
            pickup_hour = int(rng.choice([8, 9, 10]))
        elif category in (
            "BAKERY",
            "SANDWICH",
            "SALAD",
            "FAST_FOOD",
            "HEALTHY",
            "BURGER",
            "PIZZA",
            "DESSERT",
        ):
            pickup_hour = int(rng.choice([12, 13, 14]))
        elif category in ("FINE_DINING", "GRILL", "BBQ", "PASTA", "SEAFOOD", "SUSHI"):
            pickup_hour = int(rng.choice([19, 20, 21]))
        else:
            pickup_hour = int(rng.integers(11, 22))

        day_of_week = int(rng.integers(0, 7))

        # Lead time distribution — most restaurants post 2-4h ahead
        time_to_pickup = float(
            rng.choice(
                [0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0],
                p=[0.04, 0.10, 0.13, 0.20, 0.23, 0.15, 0.08, 0.05, 0.02],
            )
        )

        quantity = int(np.clip(rng.integers(5, 32), 5, 35))
        discount_rate = float(np.clip(rng.normal(43, 12), 15, 75))
        visibility = "ANONYMOUS" if rng.random() < 0.33 else "IDENTIFIED"
        description_length = int(np.clip(rng.integers(15, 210), 15, 250))

        # ── Restaurant history features (expanding window — no leakage) ──────────
        # Cold start is handled at the application layer (gate: 15 offers + 21 days).
        # By the time the predictor runs, this restaurant always has real history.
        # restaurant_offer_count stays as a feature so the model distinguishes
        # an early-unlocked restaurant (15 offers) from an experienced one (200+).
        h = hist[rid]
        n_own = len(h)
        # EWM gives more weight to recent offers — a restaurant that was bad
        # but has improved recently will see its expired rate drop faster
        # than with a simple mean. span=10 means the last ~10 offers dominate.
        if n_own > 0:
            rest_past_expired = float(
                pd.Series(h).ewm(span=10, min_periods=1).mean().iloc[-1]
            )
        else:
            rest_past_expired = 0.40
        rest_offer_count = n_own

        offer_row: dict = dict(
            discount_rate=discount_rate,
            quantity=quantity,
            time_to_pickup_hours=time_to_pickup,
            pickup_hour=pickup_hour,
            day_of_week=day_of_week,
            description_length=description_length,
            category_sell_rate=cat_sell_rate,
            establishment_type=estab,
            # Rating: 0.0 is a DB default guard only — at unlock the restaurant
            # will always have real reviews. 3.5 is a null-safety fallback, not
            # a cold-start strategy.
            restaurant_avg_rating=float(rest["avg_rating"])
            if rest["avg_rating"] > 0
            else 3.5,
            restaurant_past_expired_rate=rest_past_expired,
            restaurant_offer_count=rest_offer_count,
            visibility=visibility,
        )

        # Ground-truth outcome with unobserved demand noise.
        # std=0.04: tight enough that static features remain meaningfully predictive,
        # yet noisy enough to represent real unobservable factors (weather, nearby events...).
        p_sold = float(
            np.clip(_sell_probability(offer_row) + rng.normal(0.0, 0.04), 0.05, 0.97)
        )
        sold = bool(rng.random() < p_sold)
        expired = 0 if sold else 1

        # ── Dynamic features at snapshot time (2h before pickup) ─────────────
        # Correlated with outcome but with realistic noise AND overlap between
        # the two classes. In real life:
        #   - Some sold offers have low early sell-through (bulk orders arrive late)
        #   - Some expired offers had decent views (people browsed but didn't buy)
        # Without this overlap the model ignores static features entirely.
        if sold:
            str_mu = rng.uniform(0.15, 0.60)  # wider range, less certain
            str_val = float(np.clip(rng.normal(str_mu, 0.18), 0.0, 1.0))
            views = int(max(1, quantity * rng.uniform(1.2, 3.5)))
            eng = float(
                np.clip(rng.normal(0.14, 0.08), 0.01, 0.45)
            )  # CTR: clicks / views
        else:
            str_mu = rng.uniform(0.03, 0.30)  # higher ceiling — more overlap with sold
            str_val = float(np.clip(rng.normal(str_mu, 0.14), 0.0, 0.65))
            views = int(max(1, quantity * rng.uniform(0.30, 2.00)))
            eng = float(
                np.clip(rng.normal(0.08, 0.07), 0.01, 0.32)
            )  # CTR: clicks / views

        offer_row.update(
            sell_through_rate_realtime=str_val,
            time_remaining_hours=2.0,
            view_count=views,
            engagement_rate=eng,
            expired=expired,
            offer_id=f"O{i + 1:05d}",
            restaurant_id=rid,
            category=category,
            created_at=start_date + timedelta(days=i * 90 / n_offers),
        )
        records.append(offer_row)
        hist[rid].append(expired)

    df = pd.DataFrame(records)

    # 3 % label noise — real-world labels are never perfectly clean
    # (cancelled orders re-listed, manual status corrections, etc.)
    flip = rng.random(len(df)) < 0.03
    df.loc[flip, "expired"] = 1 - df.loc[flip, "expired"]

    return df


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    os.makedirs("models", exist_ok=True)

    restaurants = generate_restaurants(n=80, seed=42)
    df = generate_offers(restaurants, n_offers=2000, seed=42)
    df.to_csv("offer_history.csv", index=False)

    exp_rate = df["expired"].mean()
    print(f"\n✅  Generated {len(df)} offers  |  expiration rate: {exp_rate:.1%}")
    print(
        f"   Restaurants: {df['restaurant_id'].nunique()}  "
        f"|  Categories: {df['category'].nunique()}\n"
    )
    print(
        df[
            [
                "discount_rate",
                "quantity",
                "time_to_pickup_hours",
                "sell_through_rate_realtime",
                "expired",
            ]
        ]
        .describe()
        .round(3)
    )
