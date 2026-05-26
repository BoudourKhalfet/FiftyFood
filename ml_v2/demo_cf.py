from generator import generate_offers, generate_restaurants
from predictor import OfferRiskPredictor

predictor = OfferRiskPredictor()
restaurants = generate_restaurants(n=80, seed=42)
df = generate_offers(restaurants, n_offers=40, seed=77)
ground_truth = df["expired"].tolist()
df = df.drop(columns=["expired"], errors="ignore")
results = predictor.predict(df)

shown = 0
for idx, (_, row) in enumerate(results.iterrows()):
    if row["risk_level"] == "HIGH" and shown < 5:
        offer = df.iloc[idx]
        actual = "EXPIRED" if ground_truth[idx] else "SOLD"
        oid = row["offer_id"]
        score = row["risk_score"]
        disc = offer["discount_rate"]
        qty = offer["quantity"]
        lead = offer["time_to_pickup_hours"]
        views = offer["view_count"]
        str_ = offer["sell_through_rate_realtime"]

        print(f"offer={oid}  score={score}  actual={actual}")
        print(
            f"  discount={disc:.1f}%  qty={qty}  lead={lead}h  views={views}  sell_through={str_:.2f}"
        )

        for f in row["top_factors"]:
            feat = f["feature"]
            val = f["value"]
            shap = f["shap_contribution"]
            cf = f["counterfactual"]

            if cf:
                sug = cf.get("suggested_value", cf.get("suggested_publish_label", "?"))
                pscore = cf.get("predicted_score", "?")
                reduc = cf.get("risk_reduction", 0.0)
                scope = cf.get("scope", "?")
                msg = cf.get("message", "")
                cf_str = f"-> suggest {feat}={sug} : predicted score={pscore}  saves -{reduc:.2f}  [{scope}]\n      Tip: {msg}"
            else:
                cf_str = "-> no counterfactual"

            print(f"  [{feat}={val}  SHAP=+{shap:.4f}]  {cf_str}")
        print()
        shown += 1
