"""
FiftyFood - Business Intelligence Report
Adapted to show specific tips and metrics for the 3 Model Types.
"""

import sys
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, recall_score, precision_score, mean_absolute_error

# Import local modules
from data_generation import generate_train_data, generate_test_data, sell_time_to_class
from features import build_category_stats, build_expiration_features
from visualization import setup_plot_style, plot_validation_grid, plot_feature_importance

def main():
    print("=" * 80)
    print("FIFTYFOOD — BUSINESS INTELLIGENCE REPORT")
    print("=" * 80)
    
    setup_plot_style()
    
    # --- DATA GENERATION ---
    print("\n[Generating Data...]")
    df_train = generate_train_data(n_offers=5000, seed=42)
    df_test = generate_test_data(n_offers=1000, seed=99)
    
    cat_stats = build_category_stats(df_train)
    X_train_exp, y_train_exp, _ = build_expiration_features(df_train, cat_stats)
    X_test_exp, y_test_exp, _ = build_expiration_features(df_test, cat_stats)

    # Keep the visual layer connected to the report with the core validation plot.
    df_offers = pd.concat([df_train, df_test], ignore_index=True)
    plot_validation_grid(df_offers)
    
    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train_exp)
    X_test_s = scaler.transform(X_test_exp)

    # ==========================================
    # MODEL 1: EXPIRATION RISK CLASSIFIER
    # ==========================================
    print("\n" + "=" * 80)
    print("MODEL 1: EXPIRATION RISK (The Safety Guard)")
    print("Goal: Prevent food waste by predicting unsold offers.")
    print("=" * 80)

    # Train Random Forest (The Winner)
    rf_exp = RandomForestClassifier(n_estimators=100, max_depth=8, random_state=42, class_weight='balanced')
    rf_exp.fit(X_train_exp, y_train_exp)
    preds_exp = rf_exp.predict(X_test_exp)
    
    # Metrics
    acc = accuracy_score(y_test_exp, preds_exp)
    rec = recall_score(y_test_exp, preds_exp) # Did we catch the waste?
    prec = precision_score(y_test_exp, preds_exp) # Are warnings trustworthy?

    print(f"\n📊 PERFORMANCE:")
    print(f"   • Trust Score (Precision): {prec:.1%} (When we warn, we are right {prec:.0%} of the time)")
    print(f"   • Safety Score (Recall):   {rec:.1%} (We caught {rec:.0%} of all expiring food)")

    plot_feature_importance(
        ['dow_0', 'dow_1', 'dow_2', 'dow_3', 'dow_4', 'dow_5', 'dow_6',
         'quantity', 'price', 'publish_hour',
         'cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity'],
        rf_exp.feature_importances_,
        title='Expiration Risk Feature Importance'
    )
    
    print(f"\n💡 SAMPLE TIPS GENERATED:")
    # Find some predicted expirations to show tips
    risk_indices = np.where(preds_exp == 1)[0][:3] # Get first 3 predicted risks
    for idx in risk_indices:
        row = df_test.iloc[idx]
        print(f"   ⚠️  ALERT: Offer #{row['offer_id']} ({row['offer_type']})")
        print(f"      Risk: High probability of expiring.")
        print(f"      👉 TIP: Reduce quantity from {int(row['quantity'])} to {int(row['quantity']*0.7)} or lower price by 15%.")

    # ==========================================
    # MODEL 2: OFFER VELOCITY CLASSIFIER
    # ==========================================
    print("\n" + "=" * 80)
    print("MODEL 2: VELOCITY PREDICTOR (The Speedometer)")
    print("Goal: Predict how fast an offer sells (Fast/Med/Slow).")
    print("=" * 80)

    # Prepare Velocity Data (Censored Regression Approach)
    MAX_TIME = 180.0
    df_train_v = df_train.copy()
    df_train_v.loc[df_train_v['expired'] == 1, 'sell_time_minutes'] = MAX_TIME
    df_test_v = df_test.copy()
    df_test_v.loc[df_test_v['expired'] == 1, 'sell_time_minutes'] = MAX_TIME
    
    # Simple feature prep for velocity (reusing logic)
    dowd_tr = pd.get_dummies(df_train_v['day_of_week'], prefix='dow').reindex(columns=[f'dow_{i}' for i in range(7)], fill_value=0)
    dfcat_tr = df_train_v.join(cat_stats, on='offer_type', how='left').fillna(0)
    X_vel_tr = pd.concat([dowd_tr, df_train_v[['quantity','price','publish_hour']], dfcat_tr[['cat_sell_rate','cat_avg_sell_time','cat_avg_quantity']]], axis=1).values
    y_vel_tr = df_train_v['sell_time_minutes'].values

    dowd_te = pd.get_dummies(df_test_v['day_of_week'], prefix='dow').reindex(columns=[f'dow_{i}' for i in range(7)], fill_value=0)
    dfcat_te = df_test_v.join(cat_stats, on='offer_type', how='left').fillna(0)
    X_vel_te = pd.concat([dowd_te, df_test_v[['quantity','price','publish_hour']], dfcat_te[['cat_sell_rate','cat_avg_sell_time','cat_avg_quantity']]], axis=1).values
    y_vel_te = df_test_v['sell_time_minutes'].values

    # Train Regressor
    reg_vel = RandomForestRegressor(n_estimators=50, random_state=42)
    reg_vel.fit(X_vel_tr, y_vel_tr)
    pred_times = reg_vel.predict(X_vel_te)
    
    mae = mean_absolute_error(y_vel_te, pred_times)
    
    print(f"\n📊 PERFORMANCE:")
    print(f"   • Timing Error: +/- {mae:.0f} minutes")
    print(f"   (The model predicts sell-speed with an average error of {mae:.0f} mins)")

    print(f"\n💡 SAMPLE TIPS GENERATED:")
    # Show 3 random predictions
    for i in [10, 20, 30]: 
        pred_min = pred_times[i]
        row = df_test.iloc[i]
        
        if pred_min < 15:
            speed = "FAST 🔥"
            tip = "Increase quantity next time! You sold out too fast."
        elif pred_min > 60:
            speed = "SLOW 🐢"
            tip = "Lower price or post earlier. This moves slowly."
        else:
            speed = "MEDIUM ⚖️"
            tip = "Standard pacing. Maintain current strategy."
            
        print(f"   ⏱️  Offer #{row['offer_id']} predicted speed: {speed} ({pred_min:.0f} min)")
        print(f"      👉 TIP: {tip}")

    # ==========================================
    # MODEL 3: PICKUP PATTERN MODEL
    # ==========================================
    print("\n" + "=" * 80)
    print("MODEL 3: PICKUP PATTERNS (The Receptionist)")
    print("Goal: Identify peak hours for staffing.")
    print("=" * 80)

    # Calculate simple stats from training data
    sold_data = df_train[df_train['expired'] == 0]
    peak_hour = sold_data['pickup_hour'].mode()[0]
    avg_hour = sold_data['pickup_hour'].mean()
    
    # Group by Day of Week
    dow_patterns = sold_data.groupby('day_of_week')['pickup_hour'].mean()
    days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
    
    print(f"\n📊 PERFORMANCE:")
    print(f"   • Most Common Pickup Time: {peak_hour:.0f}:00")
    print(f"   • Average Pickup Time:     {avg_hour:.1f}:00")

    print(f"\n💡 SAMPLE TIPS GENERATED:")
    print(f"   📅 WEEKLY SCHEDULE ADVICE:")
    for day_idx, mean_h in dow_patterns.items():
        day_name = days[int(day_idx)]
        h = int(mean_h)
        print(f"      • {day_name}: Have bags ready by {h-1}:00 (Peak pickup at {h}:00)")

    # ==========================================
    # FINAL VERDICT
    # ==========================================
    print("\n" + "=" * 80)
    print("FINAL DEPLOYMENT VERDICT")
    print("=" * 80)
    
    if rec > 0.60:
        print("✅ EXPIRATION MODEL: READY. (High Recall ensures we save food).")
    else:
        print("⚠️  EXPIRATION MODEL: NEEDS WORK. (Missing too much waste).")
        
    if mae < 45:
        print("✅ VELOCITY MODEL: GOOD. (Timing error is acceptable).")
    else:
        print("⚠️  VELOCITY MODEL: ROUGH. (Error is high, use for general guidance only).")
        
    print("✅ PICKUP MODEL: READY. (Based on solid historical averages).")

if __name__ == "__main__":
    main()