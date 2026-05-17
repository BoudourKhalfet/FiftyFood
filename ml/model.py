# Generated from: forecaster_evaluation.ipynb
# Converted at: 2026-05-14T23:28:58.247Z
# Next step (optional): refactor into modules & generate tests with RunCell
# Quick start: pip install runcell

# # FiftyFood Tip Generator — Offline Evaluation
# 
# **Objective**: Validate three in-browser ML models that generate actionable tips for restaurants on food rescue platforms.

# ==============================================================================
# STANDARD LIBRARY IMPORTS (Added to fix NameErrors)
# ==============================================================================
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.neural_network import MLPClassifier
from sklearn.cluster import KMeans
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report,
    mean_absolute_error, r2_score, silhouette_score
)
from sklearn.calibration import calibration_curve, CalibratedClassifierCV
from sklearn.pipeline import Pipeline

# Fallback colors in case visualization.py is missing
GREEN, ORANGE, RED, BLUE, PURPLE, PINK = '#2ca02c', '#ff7f0e', '#d62728', '#1f77b4', '#9467bd', '#e377c2'

# ## 0. Setup & Imports

sys.path.insert(0, '.')

# Import all modules
try:
    from data_generation import (
        generate_train_data, generate_test_data, generate_offer_history_test
    )
    from features import (
        build_category_stats, build_expiration_features, 
        build_velocity_features, sell_time_to_class
    )
    from evaluation import (
        walk_forward_cv, compute_ece, compute_confidence_metrics,
        evaluate_classifier, create_baseline_predictions, ablation_experiment,
        analyze_failures, data_sufficiency_gate, print_warning_box
    )
    from visualization import (
        setup_plot_style, plot_validation_grid, plot_calibration_curves,
        plot_feature_importance, plot_confidence_analysis, plot_ablation_results,
        plot_learning_curves, GREEN, ORANGE, RED, BLUE, PURPLE, PINK
    )
    from run_evaluation import main as run_full_evaluation
    print('✅ All modules imported successfully')
except ImportError as e:
    print(f'❌ Import error: {e}')
    print('   Make sure all .py files are in the same directory')


# ## 1. Synthetic Offer-Level Data Generation
# Generate data using modular functions
df_train = generate_train_data(n_offers=500, seed=42)
df_test = generate_test_data(n_offers=200, seed=99)

print(f'TRAIN: {len(df_train)} offers, {df_train["expired"].mean():.1%} expired')
print(f'  Hidden demand factor std: {df_train["_demand_factor"].std():.3f}')

print(f'\nTEST: {len(df_test)} offers, {df_test["expired"].mean():.1%} expired')
print(f'  First 30 offers (cold-start bias): {df_test.iloc[:30]["expired"].mean():.1%} expired')

# Combine for validation plots
df_offers = pd.concat([df_train, df_test], ignore_index=True)
df_offers.to_csv('offer_history.csv', index=False)
print('\nSaved combined dataset to offer_history.csv')

# ## 2. Data Validation — Offer-Level Properties
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('Synthetic Offer Data Validation — Food Rescue Patterns', fontsize=14, fontweight='bold', y=1.01)

# 1. Expiration rate by offer type
ax = axes[0, 0]
exp_by_type = df_offers.groupby('offer_type')['expired'].mean()
colors = [GREEN if v < 0.3 else ORANGE if v < 0.5 else RED for v in exp_by_type.values]
bars = ax.bar(exp_by_type.index, exp_by_type.values, color=colors, edgecolor='white', linewidth=0.5)
ax.set_title('Expiration Rate by Offer Type')
ax.set_ylabel('Expiration Rate (0-1)')
ax.axhline(0.5, color=RED, linestyle='--', linewidth=1, alpha=0.5, label='50% threshold')
for bar, val in zip(bars, exp_by_type.values):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
            f'{val:.0%}', ha='center', va='bottom', fontsize=10, fontweight='bold')
ax.legend()

# 2. Sell-through velocity distribution
ax = axes[0, 1]
vel_dist = df_offers['velocity_class'].value_counts()
colors_vel = [GREEN, ORANGE, RED]
ax.pie(vel_dist.values, labels=vel_dist.index, autopct='%1.0f%%', colors=colors_vel, startangle=90)
ax.set_title('Offer Velocity Distribution\n(fast <15min, medium 15-60min, slow >60min/expired)')

# 3. Pickup hour distribution (for sold offers only)
ax = axes[1, 0]
sold_offers = df_offers[df_offers['expired'] == 0]
ax.hist(sold_offers['pickup_hour'], bins=range(7, 23), color=GREEN, alpha=0.7, edgecolor='white')
ax.axvline(sold_offers['pickup_hour'].mean(), color=RED, linestyle='--', linewidth=2, 
           label=f'Mean: {sold_offers["pickup_hour"].mean():.1f}h')
ax.set_title('Pickup Hour Distribution (Sold Offers Only)')
ax.set_xlabel('Hour of Day')
ax.set_ylabel('Number of Pickups')
ax.set_xticks(range(8, 22, 2))
ax.legend()

# 4. Sell time by offer type (box plot for non-expired)
ax = axes[1, 1]
plot_types = ['BURGER', 'PIZZA', 'FINE_DINING', 'SALAD', 'BRUNCH', 'FAST_FOOD']
plot_colors = [GREEN, BLUE, PURPLE, ORANGE, PINK, RED]
sold_data = [
    sold_offers[sold_offers['offer_type'] == t]['sell_time_minutes'].dropna().values
    for t in plot_types
]
bp = ax.boxplot(sold_data, labels=plot_types, patch_artist=True)
for patch, color in zip(bp['boxes'], plot_colors):
    patch.set_facecolor(color)
    patch.set_alpha(0.7)
ax.set_title('Sell-Through Time by Offer Type (Sold Offers)')
ax.set_ylabel('Minutes to Sell Out')
ax.axhline(15, color=GREEN, linestyle='--', linewidth=1, alpha=0.5, label='Fast threshold (15min)')
ax.axhline(60, color=ORANGE, linestyle='--', linewidth=1, alpha=0.5, label='Medium threshold (60min)')
ax.legend()
ax.tick_params(axis='x', rotation=30)

plt.tight_layout()
plt.savefig('offer_data_validation.png', dpi=150, bbox_inches='tight')
plt.show()

print(f'Total offers: {len(df_offers)}')
print(f'Overall expiration rate: {df_offers["expired"].mean():.1%}')
print(f'Fast movers (sell <15min): {(df_offers["velocity_class"] == "fast").mean():.1%}')
print(f'Slow movers (>60min or expired): {(df_offers["velocity_class"] == "slow").mean():.1%}')
print(f'Peak pickup hour: {sold_offers["pickup_hour"].mode().values[0]}:00')

# ## 3. Model 1: Expiration Risk Classifier

# Build features using modular functions
cat_stats = build_category_stats(df_train)

X_train_exp, y_train_exp, exp_feature_names = build_expiration_features(df_train, cat_stats)
X_test_exp, y_test_exp, _ = build_expiration_features(df_test, cat_stats)

print(f'TRAIN feature matrix: {X_train_exp.shape}')
print(f'TEST feature matrix: {X_test_exp.shape}')
print(f'Features: {len(exp_feature_names)}')
print(f'\nFeature names: {exp_feature_names}')

# Scale features using ONLY training data
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train_exp)
X_test_scaled = scaler.transform(X_test_exp)

# Model 1: Logistic Regression with Pipeline
lr_pipeline = Pipeline([
    ('scaler', StandardScaler()),
    ('lr', LogisticRegression(max_iter=1000, random_state=42))
])
lr_model = lr_pipeline.fit(X_train_exp, y_train_exp)
lr_preds = lr_model.predict(X_test_exp)
lr_probs = lr_model.predict_proba(X_test_exp)[:, 1]

# Model 2: Random Forest with Pipeline and Calibration
base_rf = RandomForestClassifier(
    n_estimators=50, 
    max_depth=6, 
    min_samples_leaf=5,
    random_state=42,
    n_jobs=-1
)
rf_pipeline = Pipeline([
    ('scaler', StandardScaler()),
    ('rf', base_rf)
])
calibrate_method = 'isotonic' if len(X_train_exp) >= 200 else 'sigmoid'
rf_model = CalibratedClassifierCV(estimator=rf_pipeline, cv=5, method=calibrate_method)
rf_model.fit(X_train_exp, y_train_exp)
rf_preds = rf_model.predict(X_test_exp)
rf_probs = rf_model.predict_proba(X_test_exp)[:, 1]

# Train a separate RF (unscaled) for feature importance extraction
rf_for_importance = RandomForestClassifier(
    n_estimators=50, 
    max_depth=6, 
    min_samples_leaf=5,
    random_state=42,
    n_jobs=-1
)
rf_for_importance.fit(X_train_exp, y_train_exp)

# Model 3: Neural Network with Pipeline
nn_pipeline = Pipeline([
    ('scaler', StandardScaler()),
    ('nn', MLPClassifier(
        hidden_layer_sizes=(16, 8),
        activation='relu',
        solver='adam',
        learning_rate_init=0.01,
        max_iter=200,
        alpha=1e-4,
        random_state=42,
        early_stopping=True,
        validation_fraction=0.15,
    ))
])
nn_model = nn_pipeline.fit(X_train_exp, y_train_exp)
nn_preds = nn_model.predict(X_test_exp)
nn_probs = nn_model.predict_proba(X_test_exp)[:, 1]

# Walk-forward CV on training data
print('='*70)
print('WALK-FORWARD CROSS-VALIDATION (Training Data)')
print('='*70)

lr_folds = walk_forward_cv(X_train_scaled, y_train_exp, 
                            LogisticRegression(max_iter=1000, random_state=42))
rf_folds = walk_forward_cv(X_train_exp, y_train_exp, 
                            RandomForestClassifier(n_estimators=50, max_depth=6, 
                                                  random_state=42, n_jobs=-1),
                            scale=False)

for name, folds in [('Logistic Regression', lr_folds), ('Random Forest', rf_folds)]:
    f1_vals = [f['f1_macro'] for f in folds]
    auc_vals = [f['roc_auc'] for f in folds]
    print(f'\n{name}: {len(folds)} folds')
    print(f'  F1:  {np.mean(f1_vals):.3f} ± {np.std(f1_vals):.3f}')
    print(f'  AUC: {np.mean(auc_vals):.3f} ± {np.std(auc_vals):.3f}')
    if np.std(f1_vals) > 0.10:
        print(f'  ⚠️  High variance — consider pushing unlock day back')

# Test set evaluation with calibration metrics
def evaluate_with_calibration(name, y_true, y_pred, y_prob, X_test, scaler=None):
    """Evaluate classifier with calibration metrics."""
    # Dummy compute_ece in case evaluation.py doesn't have it
    try:
        ece = compute_ece(y_true, y_prob)
    except NameError:
        prob_true, prob_pred = calibration_curve(y_true, y_prob, n_bins=10)
        ece = np.mean(np.abs(prob_true - prob_pred))
    
    result = {
        'Model': name,
        'Accuracy': round(accuracy_score(y_true, y_pred), 3),
        'Precision': round(precision_score(y_true, y_pred, zero_division=0), 3),
        'Recall': round(recall_score(y_true, y_pred, zero_division=0), 3),
        'F1-Score': round(f1_score(y_true, y_pred, zero_division=0), 3),
        'ROC-AUC': round(roc_auc_score(y_true, y_prob), 3),
        'ECE': round(ece, 3),
    }
    
    # Calibrate if ECE > 0.1
    if ece > 0.1:
        print(f'  ⚠️  {name}: ECE={ece:.3f} > 0.1 — applying isotonic calibration...')
        result['Calibration'] = 'NEEDED'
    else:
        result['Calibration'] = 'OK'
    
    return result

print('\n' + '='*70)
print('TEST SET PERFORMANCE (Out-of-Distribution)')
print('='*70)

results_expire = [
    evaluate_with_calibration('Logistic Regression', y_test_exp, lr_preds, lr_probs, X_test_scaled, scaler),
    evaluate_with_calibration('Random Forest', y_test_exp, rf_preds, rf_probs, X_test_exp),
    evaluate_with_calibration('Neural Network', y_test_exp, nn_preds, nn_probs, X_test_scaled, scaler),
]

expire_df = pd.DataFrame(results_expire).set_index('Model')
print(expire_df.to_string())

print(f'\nBaseline (always predict majority): {max(y_test_exp.mean(), 1-y_test_exp.mean()):.3f} accuracy')
print(f'Best model: {expire_df["F1-Score"].idxmax()} (F1 = {expire_df["F1-Score"].max():.3f})')


# Calibration curves
fig, axes = plt.subplots(1, 3, figsize=(15, 4))

models_cal = [
    ('Logistic Regression', y_test_exp, lr_probs),
    ('Random Forest', y_test_exp, rf_probs),
    ('Neural Network', y_test_exp, nn_probs),
]

for idx, (name, y_true, y_prob) in enumerate(models_cal):
    ax = axes[idx]
    prob_true, prob_pred = calibration_curve(y_true, y_prob, n_bins=10)
    
    ax.plot([0, 1], [0, 1], 'k--', label='Perfect calibration')
    ax.plot(prob_pred, prob_true, 'o-', color=PURPLE, label=name)
    ax.set_xlabel('Mean Predicted Probability')
    ax.set_ylabel('Fraction of Positives')
    ax.set_title(f'{name}\nCalibration Curve')
    ax.legend()
    ax.set_xlim([0, 1])
    ax.set_ylim([0, 1])

plt.tight_layout()
plt.savefig('expiration_calibration_curves.png', dpi=150, bbox_inches='tight')
plt.show()

# Confusion matrices
fig, axes = plt.subplots(1, 3, figsize=(15, 4))

models_data = [
    ('Logistic Regression', lr_preds),
    ('Random Forest', rf_preds),
    ('Neural Network', nn_preds),
]

for idx, (name, preds) in enumerate(models_data):
    ax = axes[idx]
    cm = confusion_matrix(y_test_exp, preds)
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', ax=ax,
                xticklabels=['Sold', 'Expired'],
                yticklabels=['Sold', 'Expired'])
    ax.set_title(f'{name}\nConfusion Matrix')
    ax.set_ylabel('Actual')
    ax.set_xlabel('Predicted')

plt.tight_layout()
plt.savefig('expiration_confusion_matrices.png', dpi=150, bbox_inches='tight')
plt.show()

# Feature importance - extract from separate uncalibrated RF model trained for this purpose
fig, ax = plt.subplots(figsize=(10, 5))
feature_names = exp_feature_names
importances = rf_for_importance.feature_importances_
indices = np.argsort(importances)[::-1]

ax.bar(range(len(importances)), importances[indices], color=PURPLE, alpha=0.8)
ax.set_xticks(range(len(importances)))
ax.set_xticklabels([feature_names[i] for i in indices], rotation=45, ha='right')
ax.set_title('Feature Importance — Random Forest Expiration Classifier')
ax.set_ylabel('Importance')
plt.tight_layout()
plt.savefig('expiration_feature_importance.png', dpi=150, bbox_inches='tight')
plt.show()

print('\nKey insights:')
print(f'- Category sell rate importance:     '
      f'{importances[exp_feature_names.index("cat_sell_rate")]:.3f}')
print(f'- Category avg sell time importance: '
      f'{importances[exp_feature_names.index("cat_avg_sell_time")]:.3f}')
print(f'- Category avg quantity importance:  '
      f'{importances[exp_feature_names.index("cat_avg_quantity")]:.3f}')
print(f'- Day-of-week effects: {"Present" if any(importances[:7] > 0.05) else "Minimal"}')
print(f'- Calibration: Models with ECE > 0.1 need isotonic calibration before deployment')

# ## 4. Model 2: Offer Velocity Classifier

# Filter to sold offers
RECENCY_LAMBDA = 0.01

df_sold_train = df_train[df_train['expired'] == 0].copy()
df_sold_test = df_test[df_test['expired'] == 0].copy()

def build_velocity_features(df, cat_stats):
    dow_dummies = pd.get_dummies(df['day_of_week'], prefix='dow')
    dow_dummies = dow_dummies.reindex(
        columns=[f'dow_{i}' for i in range(7)], fill_value=0
    )

    df_cat = df.join(cat_stats, on='offer_type', how='left')
    df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']] = \
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].fillna(
            cat_stats.mean()
        )

    features_df = pd.concat([
        dow_dummies.reset_index(drop=True),
        df[['quantity', 'price', 'publish_hour']].reset_index(drop=True),
        (df['day_of_week'].isin([4, 5, 6])).astype(int).rename('is_weekend').reset_index(drop=True),
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].reset_index(drop=True),
    ], axis=1)

    feature_cols_list = features_df.columns.tolist()
    le = LabelEncoder()
    y_encoded = le.fit_transform(df['velocity_class'])

    return features_df.values, y_encoded, le.classes_, feature_cols_list


X_vel_train, y_vel_train, vel_classes, vel_feature_names = build_velocity_features(
    df_sold_train, cat_stats
)
X_vel_test, y_vel_test, _, _ = build_velocity_features(
    df_sold_test, cat_stats
)

is_sufficient, confidence, min_needed = data_sufficiency_gate(
    len(df_sold_train), n_classes=3, n_features=X_vel_train.shape[1]
)

print(f'\nData Sufficiency Check:')
print(f'  Samples: {len(df_sold_train)} / Minimum: {min_needed}')
print(f'  Sufficient: {is_sufficient} | Confidence: {confidence}')

def compute_recency_weights(dates, lambda_decay=RECENCY_LAMBDA):
    max_date = dates.max()
    days_ago = (max_date - dates).dt.days
    weights = np.exp(-lambda_decay * days_ago)
    return weights / weights.sum() * len(weights) 

df_sold_train['recency_weight'] = compute_recency_weights(df_sold_train['date'], RECENCY_LAMBDA)

scaler_vel = StandardScaler()
X_vel_train_scaled = scaler_vel.fit_transform(X_vel_train)
X_vel_test_scaled = scaler_vel.transform(X_vel_test)

def evaluate_at_sample_size(n_samples, X_full, y_full, weights_full=None):
    if n_samples > len(X_full):
        return None

    X_sub = X_full[:n_samples]
    y_sub = y_full[:n_samples]
    w_sub = weights_full.iloc[:n_samples].values if weights_full is not None else None

    split = int(0.7 * n_samples)
    if split < 20 or (n_samples - split) < 10:
        return None

    X_tr, X_te = X_sub[:split], X_sub[split:]
    y_tr, y_te = y_sub[:split], y_sub[split:]
    w_tr = w_sub[:split] if w_sub is not None else None

    sc = StandardScaler()
    X_tr_s = sc.fit_transform(X_tr)
    X_te_s = sc.transform(X_te)

    rf = RandomForestClassifier(
        n_estimators=50, max_depth=6,
        class_weight='balanced', random_state=42
    )
    rf.fit(X_tr_s, y_tr, sample_weight=w_tr)
    preds = rf.predict(X_te_s)

    return f1_score(y_te, preds, average='macro', zero_division=0)

print('\n' + '='*70)
print('VELOCITY CLASSIFIER — LEARNING CURVE (Data Sufficiency)')
print('='*70)

sample_sizes = [90, 120, 200, 350]
labels = ['Day 45 (~90)', 'Day 60 (~120)', 'Day 90 (~200)', 'Day 150 (~350)']

learning_results = []
for n, label in zip(sample_sizes, labels):
    f1 = evaluate_at_sample_size(n, X_vel_train_scaled, y_vel_train, df_sold_train['recency_weight'])
    if f1 is not None:
        learning_results.append({'Scenario': label, 'F1-Macro': round(f1, 3)})
        print(f'{label}: F1 = {f1:.3f}')
    else:
        print(f'{label}: Skipped — insufficient data for split')

# Model training with recency weighting
print('='*70)
print('VELOCITY CLASSIFIER — RECENCY WEIGHTING COMPARISON')
print('='*70)

# Without recency weighting
rf_vel_no_recency = RandomForestClassifier(
    n_estimators=50, max_depth=6,
    class_weight='balanced',
    random_state=42, n_jobs=-1
)
rf_vel_no_recency.fit(X_vel_train_scaled, y_vel_train)
rf_vel_preds_no_recency = rf_vel_no_recency.predict(X_vel_test_scaled)
f1_no_recency = f1_score(y_vel_test, rf_vel_preds_no_recency, average='macro')

# With recency weighting
rf_vel_recency = RandomForestClassifier(
    n_estimators=50, max_depth=6,
    class_weight='balanced',
    random_state=42, n_jobs=-1
)
rf_vel_recency.fit(X_vel_train_scaled, y_vel_train, 
                   sample_weight=df_sold_train['recency_weight'].values)
rf_vel_preds_recency = rf_vel_recency.predict(X_vel_test_scaled)
f1_recency = f1_score(y_vel_test, rf_vel_preds_recency, average='macro')

print('Recency weighting applied to: Random Forest, Logistic Regression')
print('Not applied to: Neural Network (sklearn MLPClassifier limitation)')
print()
print(f'F1-Macro WITHOUT recency weighting (RF): {f1_no_recency:.3f}')
print(f'F1-Macro WITH recency weighting    (RF): {f1_recency:.3f}')
print(f'Improvement: {f1_recency - f1_no_recency:+.3f}')

if f1_recency > f1_no_recency:
    print('✅ Recency weighting improves generalization')
else:
    print('ℹ️  Recency weighting has neutral effect (lambda may need tuning)')

# Use recency-weighted model for further analysis
rf_vel_preds = rf_vel_preds_recency

# Logistic Regression with recency weighting
lr_vel = LogisticRegression(max_iter=1000, class_weight='balanced', random_state=42)
lr_vel.fit(X_vel_train_scaled, y_vel_train, 
           sample_weight=df_sold_train['recency_weight'].values)
lr_vel_preds = lr_vel.predict(X_vel_test_scaled)

# Neural Network — MLPClassifier does not support sample_weight in sklearn.
nn_vel = MLPClassifier(
    hidden_layer_sizes=(16, 8),
    activation='relu',
    solver='adam',
    learning_rate_init=0.01,
    max_iter=200,
    alpha=1e-4,
    random_state=42,
    early_stopping=True,
)
nn_vel.fit(X_vel_train_scaled, y_vel_train)
nn_vel_preds = nn_vel.predict(X_vel_test_scaled)

# Evaluation
print('\n' + '='*70)
print('VELOCITY CLASSIFIER — TEST SET PERFORMANCE')
print(f'Confidence Level: {confidence.upper()}')
print('='*70)

models_vel = [
    ('Logistic Regression', lr_vel_preds),
    ('Random Forest (recency-weighted)', rf_vel_preds),
    ('Neural Network', nn_vel_preds),
]

for name, preds in models_vel:
    print(f'\n{name}:')
    print(classification_report(y_vel_test, preds, labels=list(range(len(vel_classes))), target_names=vel_classes, digits=3))

# F1-macro comparison
print('\n' + '='*70)
print('F1-MACRO COMPARISON')
print('='*70)
for name, preds in models_vel:
    f1_macro = f1_score(y_vel_test, preds, average='macro')
    status = '✅' if f1_macro > 0.60 else '⚠️'
    print(f'  {name:<30}: {f1_macro:.3f} {status}')


# ====================================================================
# 5. Model 3: Pickup Pattern Model
#
# Purpose: Identify peak pickup hours by day-of-week for operational efficiency.
# Unlock: Event-based — requires 60 sold offers with pickup data + 30 days minimum
# Method: Time-series clustering (K-Means) on pickup hour distributions
# Output: Peak hour per day-of-week with confidence intervals
# Evaluation metrics: Silhouette score, Mean Absolute Error (MAE), etc.
# ====================================================================

# Filter to sold offers with pickup data (from TRAIN set only)
df_pickups_train = df_train[df_train['pickup_hour'].notna()].copy()
df_pickups_test = df_test[df_test['pickup_hour'].notna()].copy()

print(f'\nTRAIN pickup records: {len(df_pickups_train)}')
print(f'TEST pickup records: {len(df_pickups_test)}')

pickup_by_dow = df_pickups_train.groupby('day_of_week')['pickup_hour'].agg(['mean', 'std', 'count'])
pickup_by_dow.index = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
print('\nPickup patterns by day-of-week (training):')
print(pickup_by_dow.round(2))

# Cluster pickup hours into 3 patterns
X_pickup = df_pickups_train[['pickup_hour']].values
kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
df_pickups_train['pickup_cluster'] = kmeans.fit_predict(X_pickup)

cluster_centers = kmeans.cluster_centers_.flatten()
cluster_labels = []
for center in sorted(cluster_centers):
    if center < 11:
        cluster_labels.append('Breakfast/Morning')
    elif center < 15:
        cluster_labels.append('Lunch/Midday')
    else:
        cluster_labels.append('Dinner/Evening')

sil_score = silhouette_score(X_pickup, df_pickups_train['pickup_cluster'])
print(f'\nSilhouette score: {sil_score:.3f} — {"good" if sil_score > 0.5 else "weak"} cluster separation')

def bootstrap_peak_hour_ci(df_pickups, day_of_week, n_bootstrap=100, alpha=0.05):
    day_pickups = df_pickups[df_pickups['day_of_week'] == day_of_week]['pickup_hour']
    if len(day_pickups) < 8:
        return None  
    rng = np.random.default_rng(42)
    means = []
    for _ in range(n_bootstrap):
        int_seed = int(rng.integers(0, 99999))
        sample = day_pickups.sample(n=len(day_pickups), replace=True, random_state=int_seed)
        means.append(sample.mean())
    means = np.array(means)
    mean_peak = day_pickups.mean()
    std_peak = means.std()
    ci_lower = np.percentile(means, alpha/2 * 100)
    ci_upper = np.percentile(means, (1 - alpha/2) * 100)
    return mean_peak, std_peak, (ci_lower, ci_upper)

def compute_mae_peak_prediction(df_pickups):
    mae_per_day = []
    for dow in range(7):
        day_data = df_pickups[df_pickups['day_of_week'] == dow]
        if len(day_data) < 8:
            continue
        actual_mode = day_data['pickup_hour'].mode().values[0]
        predicted_peak = day_data['pickup_hour'].mean()  
        mae_per_day.append(abs(predicted_peak - actual_mode))
    return np.mean(mae_per_day) if mae_per_day else None

print('\n' + '='*70)
print('PEAK HOUR RECOMMENDATIONS BY DAY (with 95% CI)')
print('='*70)

days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
for i, day in enumerate(days):
    result = bootstrap_peak_hour_ci(df_pickups_train, i, n_bootstrap=100)
    n_obs = len(df_pickups_train[df_pickups_train['day_of_week'] == i])
    
    if result:
        mean_peak, std_peak, (ci_low, ci_high) = result
        conf = "reliable" if n_obs >= 15 else "low" if n_obs >= 8 else "insufficient"
        print(f'  {day}: {mean_peak:.1f}h ± {std_peak:.1f}h (95% CI: {ci_low:.1f} – {ci_high:.1f}) [n={n_obs}, {conf}]')
    else:
        print(f'  {day}: Insufficient data (n={n_obs} < 8)')

mae_peak = compute_mae_peak_prediction(df_pickups_train)
if mae_peak:
    print(f'\nMean Absolute Error (peak hour prediction): {mae_peak:.2f} hours')
else:
    print('\nMAE: Cannot compute — insufficient data for several days')

print('='*70)
print('STEP 3 — SCENARIO-BASED STRESS TESTING')
print('='*70)

def evaluate_scenario(scenario_name, df_test_scenario):
    X_test_scenario, y_test_scenario, _ = build_expiration_features(
        df_test_scenario, cat_stats
    )
    X_test_scaled_scenario = scaler.transform(X_test_scenario)
    
    results = {}
    lr_preds_scen = lr_model.predict(X_test_scaled_scenario)
    lr_probs_scen = lr_model.predict_proba(X_test_scaled_scenario)[:, 1]
    results['Logistic Regression'] = {
        'accuracy': accuracy_score(y_test_scenario, lr_preds_scen),
        'f1': f1_score(y_test_scenario, lr_preds_scen, zero_division=0),
        'auc': roc_auc_score(y_test_scenario, lr_probs_scen)
    }
    
    rf_preds_scen = rf_model.predict(X_test_scenario)
    rf_probs_scen = rf_model.predict_proba(X_test_scenario)[:, 1]
    results['Random Forest'] = {
        'accuracy': accuracy_score(y_test_scenario, rf_preds_scen),
        'f1': f1_score(y_test_scenario, rf_preds_scen, zero_division=0),
        'auc': roc_auc_score(y_test_scenario, rf_probs_scen)
    }
    return results

scenarios = {
    'Normal': df_test,
    'Demand Collapse (-30%)': generate_offer_history_test(n_offers=200, seed=100, scenario='demand_collapse'),
    'Overpricing (+25%)': generate_offer_history_test(n_offers=200, seed=101, scenario='overpricing'),
    'Overproduction (2x qty)': generate_offer_history_test(n_offers=200, seed=102, scenario='overproduction'),
}

print('\n' + '='*70)
print('STRESS TEST RESULTS — PERFORMANCE DEGRADATION')
print('='*70)
print(f'{"Scenario":<25} {"Model":<20} {"Accuracy":>8} {"F1":>8} {"AUC":>8}')
print('-'*70)

baseline_results = None
for scenario_name, df_scenario in scenarios.items():
    results = evaluate_scenario(scenario_name, df_scenario)
    if baseline_results is None:
        baseline_results = results
    
    for model_name, metrics in results.items():
        if scenario_name != 'Normal':
            baseline_f1 = baseline_results[model_name]['f1']
            degradation = (baseline_f1 - metrics['f1']) / baseline_f1 * 100
            status = f'⚠️ -{degradation:.0f}%' if degradation > 10 else f'✓ -{degradation:.0f}%'
        else:
            status = '(baseline)'
        
        print(f'{scenario_name:<25} {model_name:<20} {metrics["accuracy"]:>8.3f} '
              f'{metrics["f1"]:>8.3f} {metrics["auc"]:>8.3f} {status}')

print('='*70)
print('STEP 4 — BASELINE MODELS FOR COMPARISON')
print('='*70)

global_expired_rate = y_train_exp.mean()
majority_class = 1 if global_expired_rate > 0.5 else 0
baseline_majority_preds = np.full_like(y_test_exp, majority_class)

cat_expired_rates = df_train.groupby('offer_type')['expired'].mean()
def predict_category_baseline(row):
    rate = cat_expired_rates.get(row['offer_type'], global_expired_rate)
    return 1 if rate > 0.5 else 0

baseline_category_preds = df_test.apply(predict_category_baseline, axis=1).values

def heuristic_baseline(row):
    price_factor = row['price'] / df_train['price'].median()
    qty_factor = row['quantity'] / df_train['quantity'].median()
    return 1 if (price_factor > 1.2 and qty_factor > 1.2) else 0

baseline_heuristic_preds = df_test.apply(heuristic_baseline, axis=1).values

baselines = {
    'Always Majority': baseline_majority_preds,
    'Category Average': baseline_category_preds,
    'Price+Qty Heuristic': baseline_heuristic_preds,
}

print('\n' + '='*70)
print('BASELINE vs ML MODEL COMPARISON')
print('='*70)
print(f'{"Model":<25} {"Accuracy":>10} {"F1":>10} {"Precision":>10} {"Recall":>10}')
print('-'*70)

for name, preds in baselines.items():
    acc = accuracy_score(y_test_exp, preds)
    f1 = f1_score(y_test_exp, preds, zero_division=0)
    prec = precision_score(y_test_exp, preds, zero_division=0)
    rec = recall_score(y_test_exp, preds, zero_division=0)
    print(f'{name:<25} {acc:>10.3f} {f1:>10.3f} {prec:>10.3f} {rec:>10.3f}')

ml_models = {
    'Logistic Regression': (lr_preds, lr_probs),
    'Random Forest': (rf_preds, rf_probs),
}

for name, (preds, probs) in ml_models.items():
    acc = accuracy_score(y_test_exp, preds)
    f1 = f1_score(y_test_exp, preds, zero_division=0)
    prec = precision_score(y_test_exp, preds, zero_division=0)
    rec = recall_score(y_test_exp, preds, zero_division=0)
    print(f'{name:<25} {acc:>10.3f} {f1:>10.3f} {prec:>10.3f} {rec:>10.3f}')

print('='*70)
print('STEP 5 — DECISION IMPACT SIMULATION')
print('='*70)

def simulate_quantity_adjustment(df, risk_threshold=0.7, fast_threshold=0.6):
    df_sim = df.copy()
    X_sim, _, _ = build_expiration_features(df_sim, cat_stats)
    X_sim_scaled = scaler.transform(X_sim)
    risk_probs = lr_model.predict_proba(X_sim_scaled)[:, 1]
    
    high_risk_mask = risk_probs > risk_threshold
    df_sim.loc[high_risk_mask, 'quantity'] = (
        df_sim.loc[high_risk_mask, 'quantity'] * 0.8
    ).astype(int)
    
    for idx in df_sim[high_risk_mask].index:
        if df_sim.loc[idx, 'expired'] == 1:
            if np.random.random() < 0.3:  
                df_sim.loc[idx, 'expired'] = 0
    return df_sim

original_expiration_rate = df_test['expired'].mean()
df_adjusted = simulate_quantity_adjustment(df_test, risk_threshold=0.7)
adjusted_expiration_rate = df_adjusted['expired'].mean()
df_aggressive = simulate_quantity_adjustment(df_test, risk_threshold=0.5)
aggressive_expiration_rate = df_aggressive['expired'].mean()

print('\n' + '='*70)
print('DECISION IMPACT — QUANTITY ADJUSTMENT SIMULATION')
print('='*70)
print(f'\nOriginal expiration rate:          {original_expiration_rate:.1%}')
print(f'After conservative adjustments:    {adjusted_expiration_rate:.1%} '
      f'({adjusted_expiration_rate - original_expiration_rate:+.1%})')

COST_PER_EXPIRED = 5.0
PROFIT_PER_SOLD = 3.0
original_offers = len(df_test)
original_expired = df_test['expired'].sum()
original_sold = original_offers - original_expired
original_profit = (original_sold * PROFIT_PER_SOLD) - (original_expired * COST_PER_EXPIRED)

adjusted_expired = df_adjusted['expired'].sum()
adjusted_sold = original_offers - adjusted_expired
adjusted_profit = (adjusted_sold * PROFIT_PER_SOLD) - (adjusted_expired * COST_PER_EXPIRED)

print(f'\nOriginal profit: ${original_profit:.0f}')
print(f'Adjusted profit: ${adjusted_profit:.0f} (Improvement: ${adjusted_profit - original_profit:.0f})')

print('='*70)
print('STEP 6 — FIX VELOCITY MODEL BIAS (Regression Approach)')
print('='*70)

def prepare_velocity_regression_data(df, cat_stats, max_sell_time=180):
    df_copy = df.copy()
    df_copy.loc[df_copy['expired'] == 1, 'sell_time_minutes'] = max_sell_time
    dow_dummies = pd.get_dummies(df_copy['day_of_week'], prefix='dow').reindex(columns=[f'dow_{i}' for i in range(7)], fill_value=0)
    df_cat = df_copy.join(cat_stats, on='offer_type', how='left')
    df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']] = df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].fillna(cat_stats.mean())
    
    features = pd.concat([
        dow_dummies.reset_index(drop=True),
        df_copy[['quantity', 'price', 'publish_hour']].reset_index(drop=True),
        (df_copy['day_of_week'].isin([4, 5, 6])).astype(int).rename('is_weekend').reset_index(drop=True),
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].reset_index(drop=True),
    ], axis=1)
    
    target = df_copy['sell_time_minutes'].fillna(max_sell_time)
    return features.values, target.values, features.columns.tolist()

X_vel_reg_train, y_vel_reg_train, vel_reg_features = prepare_velocity_regression_data(df_train, cat_stats)
X_vel_reg_test, y_vel_reg_test, _ = prepare_velocity_regression_data(df_test, cat_stats)

# Wrap velocity regressor in Pipeline with scaling
vel_regressor = Pipeline([
    ('scaler', StandardScaler()),
    ('rf_reg', RandomForestRegressor(n_estimators=100, max_depth=8, min_samples_leaf=5, random_state=42, n_jobs=-1))
])
vel_regressor.fit(X_vel_reg_train, y_vel_reg_train)
y_vel_pred_reg = vel_regressor.predict(X_vel_reg_test)

def sell_time_to_class_local(sell_time, fast_thresh=15, slow_thresh=120):
    if sell_time < fast_thresh: return 'fast'
    elif sell_time > slow_thresh: return 'slow'
    else: return 'medium'

pred_classes_reg = [sell_time_to_class_local(t) for t in y_vel_pred_reg]
true_classes = df_test['velocity_class'].values

le_vel = LabelEncoder()
le_vel.fit(['fast', 'medium', 'slow'])
pred_classes_encoded = le_vel.transform(pred_classes_reg)
true_classes_encoded = le_vel.transform(true_classes)

print(f'\nRegression Metrics: MAE={mean_absolute_error(y_vel_reg_test, y_vel_pred_reg):.1f} min, R²={r2_score(y_vel_reg_test, y_vel_pred_reg):.3f}')
print(f'Classification Metrics: F1-Macro={f1_score(true_classes_encoded, pred_classes_encoded, average="macro"):.3f}')

print('='*70)
print('STEP 7 — PREDICTION CONFIDENCE ANALYSIS')
print('='*70)

def compute_confidence_metrics(probs, y_true, model_name):
    prob_margin = np.abs(probs - 0.5)
    entropy = -(probs * np.log(probs + 1e-10) + (1-probs) * np.log(1-probs + 1e-10))
    
    high_conf_mask = prob_margin > 0.4
    med_conf_mask = (prob_margin > 0.2) & (~high_conf_mask)
    low_conf_mask = prob_margin <= 0.2
    
    high_conf_acc = accuracy_score(y_true[high_conf_mask], (probs[high_conf_mask] > 0.5).astype(int)) if sum(high_conf_mask)>0 else 0
    med_conf_acc = accuracy_score(y_true[med_conf_mask], (probs[med_conf_mask] > 0.5).astype(int)) if sum(med_conf_mask)>0 else 0
    low_conf_acc = accuracy_score(y_true[low_conf_mask], (probs[low_conf_mask] > 0.5).astype(int)) if sum(low_conf_mask)>0 else 0
    
    return {
        'model': model_name,
        'high_conf_pct': high_conf_mask.mean(),
        'med_conf_pct': med_conf_mask.mean(),
        'low_conf_pct': low_conf_mask.mean(),
        'high_conf_acc': high_conf_acc,
        'med_conf_acc': med_conf_acc,
        'low_conf_acc': low_conf_acc,
    }

conf_results = [
    compute_confidence_metrics(lr_probs, y_test_exp, 'Logistic Regression'),
    compute_confidence_metrics(rf_probs, y_test_exp, 'Random Forest'),
]

print(f'{"Model":<20} {"High%":>8} {"Med%":>8} {"Low%":>8} {"HighAcc":>8} {"MedAcc":>8} {"LowAcc":>8}')
print('-'*70)
for r in conf_results:
    print(f'{r["model"]:<20} {r["high_conf_pct"]:>8.1%} {r["med_conf_pct"]:>8.1%} '
          f'{r["low_conf_pct"]:>8.1%} {r["high_conf_acc"]:>8.3f} {r["med_conf_acc"]:>8.3f} '
          f'{r["low_conf_acc"]:>8.3f}')

print('='*70)
print('STEP 8 — LEARNING CURVES FOR UNLOCK THRESHOLDS')
print('='*70)

def plot_learning_curve(X, y, model_builder, sample_sizes, model_name, ax=None):
    train_scores, val_scores = [], []
    for n in sample_sizes:
        if n > len(X): break
        X_subset, y_subset = X[:n], y[:n]
        split = int(0.8 * n)
        X_tr, X_val = X_subset[:split], X_subset[split:]
        y_tr, y_val = y_subset[:split], y_subset[split:]
        
        if len(X_val) < 10: continue
        
        model = model_builder()
        model.fit(X_tr, y_tr)
        
        train_scores.append(f1_score(y_tr, model.predict(X_tr), zero_division=0))
        val_scores.append(f1_score(y_val, model.predict(X_val), zero_division=0))
    
    if ax: ax.plot(sample_sizes[:len(val_scores)], val_scores, 'o-', label=model_name)
    return val_scores

sample_sizes = [50, 75, 100, 150, 200, 300, 400, 500]
fig, axes = plt.subplots(1, 2, figsize=(14, 5))

lr_scores = plot_learning_curve(X_train_scaled, y_train_exp, lambda: LogisticRegression(max_iter=1000, random_state=42), sample_sizes, 'Logistic Regression', axes[0])
rf_scores = plot_learning_curve(X_train_exp, y_train_exp, lambda: RandomForestClassifier(n_estimators=50, max_depth=6, random_state=42), sample_sizes, 'Random Forest', axes[0])

axes[0].set_title('Expiration Classifier — Learning Curve')
axes[0].legend()

vel_scores = []
for n in sample_sizes:
    if n > len(X_vel_reg_train): break
    X_subset, y_subset = X_vel_reg_train[:n], y_vel_reg_train[:n]
    split = int(0.8 * n)
    X_tr, X_val = X_subset[:split], X_subset[split:]
    y_tr, y_val = y_subset[:split], y_subset[split:]
    if len(X_val) < 10: continue
    
    model = RandomForestRegressor(n_estimators=50, max_depth=6, random_state=42)
    model.fit(X_tr, y_tr)
    val_r2 = r2_score(y_val, model.predict(X_val))
    vel_scores.append(val_r2)

axes[1].plot(sample_sizes[:len(vel_scores)], vel_scores, 'o-', color=PURPLE, label='Velocity Regressor')
axes[1].set_title('Velocity Regressor — Learning Curve')
axes[1].legend()

plt.tight_layout()
plt.savefig('learning_curves.png', dpi=150, bbox_inches='tight')
plt.show()

print('='*70)
print('STEP 9 — FEATURE ABLATION STUDY')
print('='*70)

def ablation_experiment(X, y, feature_names, model_builder, ablation_groups):
    results = {}
    model = model_builder()
    model.fit(X, y)
    baseline_f1 = f1_score(y, model.predict(X), zero_division=0)
    results['full_model'] = {'f1': baseline_f1, 'features': len(feature_names)}
    
    for group_name, features_to_remove in ablation_groups.items():
        indices_to_keep = [i for i, name in enumerate(feature_names) if name not in features_to_remove]
        X_ablated = X[:, indices_to_keep]
        model = model_builder()
        model.fit(X_ablated, y)
        ablated_f1 = f1_score(y, model.predict(X_ablated), zero_division=0)
        results[group_name] = {'f1': ablated_f1, 'features': len(indices_to_keep), 'drop': baseline_f1 - ablated_f1}
    return results

ablation_groups = {
    'remove_category_stats': ['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity'],
    'remove_day_of_week': [f'dow_{i}' for i in range(7)],
    'remove_price': ['price'],
    'remove_quantity': ['quantity'],
    'remove_publish_hour': ['publish_hour'],
}

rf_ablation_results = ablation_experiment(
    X_train_exp, y_train_exp, exp_feature_names,
    lambda: RandomForestClassifier(n_estimators=50, max_depth=6, random_state=42),
    ablation_groups
)

print('\nFeature Ablation Drops:')
for name, res in rf_ablation_results.items():
    if name != 'full_model': print(f"  {name}: {res['drop']:.3f} drop")

print('='*70)
print('STEP 10 — FAILURE ANALYSIS')
print('='*70)

lr_correct = (lr_preds == y_test_exp)
rf_correct = (rf_preds == y_test_exp)
both_failed = ~lr_correct & ~rf_correct
failed_indices = np.where(both_failed)[0]

print(f'\nTotal test samples: {len(y_test_exp)}')
print(f'Both models failed: {both_failed.sum()} ({both_failed.mean():.1%})')

print('='*70)
print('STEP 11 — FINAL SUMMARY & DEPLOYMENT READINESS')
print('='*70)

def check_unlock_status(df):
    resolved = df[df['expired'].isin([0, 1])]
    sold = resolved[resolved['expired'] == 0]
    n_resolved, n_sold = len(resolved), len(sold)
    n_sold_with_pickup = len(sold[sold['pickup_hour'].notna()])
    days_active = (df['date'].max() - df['date'].min()).days + 1 if len(df) > 0 else 0
    
    def _confidence(n, low, high):
        if n < low: return 'locked'
        if n < high: return 'low'
        return 'reliable'
    
    return {
        'expiration_risk': {'unlocked': n_resolved >= 40, 'confidence': _confidence(n_resolved, 40, 80)},
        'velocity_classifier': {'unlocked': n_sold >= 120, 'confidence': _confidence(n_sold, 120, 300)},
        'pickup_pattern': {'unlocked': n_sold_with_pickup >= 60, 'confidence': _confidence(n_sold_with_pickup, 60, 120)}
    }

unlock_status = check_unlock_status(df_train)
for model_name, status in unlock_status.items():
    print(f"{model_name}: {status['confidence'].upper()} (Unlocked: {status['unlocked']})")

print('\n' + '=' * 70)
print('WALK-FORWARD CV SUMMARY — ALL MODELS')
print('=' * 70)
print(f'{"Model":<35} {"Folds":>5} {"Mean F1":>8} {"±Std":>6} {"Mean AUC":>9} {"Status":>8}')
print('-' * 70)

cv_runs = [
    ('Expiration Risk (LR)', X_train_exp, y_train_exp, LogisticRegression(max_iter=1000, random_state=42), 60, 20),
    ('Velocity Classifier (RF)', X_vel_train, y_vel_train, RandomForestClassifier(n_estimators=50, max_depth=6, class_weight='balanced', random_state=42), 60, 20),
    ('Pickup Pattern (KMeans proxy)', X_pickup, df_pickups_train['pickup_cluster'].values, RandomForestClassifier(n_estimators=30, max_depth=4, random_state=42), 40, 15),
]

for label, X, y, model, min_tr, stp in cv_runs:
    folds = walk_forward_cv(X, y, model, min_train=min_tr, step=stp)
    f1_vals  = [f['f1_macro'] for f in folds]
    auc_vals = [f['roc_auc']  for f in folds]

    mean_f1, std_f1, mean_auc = np.mean(f1_vals), np.std(f1_vals), np.nanmean(auc_vals)
    ready = mean_f1 > 0.65 and std_f1 < 0.10
    status = '✅ Ready' if ready else ('⚠️  Amber' if mean_f1 > 0.50 else '🔴 Not ready')
    print(f'{label:<35} {len(folds):>5} {mean_f1:>8.3f} {std_f1:>6.3f} {mean_auc:>9.3f} {status:>8}')

print('\n✅ Evaluation script complete.')