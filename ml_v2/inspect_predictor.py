import json
import numpy as np
from generator import generate_offers, generate_restaurants
from predictor import OfferRiskPredictor

def default_serializer(obj):
    if isinstance(obj, np.integer):
        return int(obj)
    if isinstance(obj, np.floating):
        return float(obj)
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    return str(obj)

def main():
    predictor = OfferRiskPredictor()
    restaurants = generate_restaurants(n=5, seed=42)
    df = generate_offers(restaurants, n_offers=5, seed=77)
    df = df.drop(columns=["expired"], errors="ignore")
    
    results = predictor.predict(df)
    
    # Convert first high risk offer to dict and print as JSON
    for idx, row in results.iterrows():
        if row["risk_level"] in ["HIGH", "MEDIUM"]:
            out = {
                "offer_id": row["offer_id"],
                "risk_score": row["risk_score"],
                "risk_level": row["risk_level"],
                "prediction_confidence": row["prediction_confidence"],
                "top_factors": row["top_factors"],
                "action_plan": row["action_plan"],
            }
            print(json.dumps(out, indent=2, default=default_serializer))
            break

if __name__ == "__main__":
    main()
