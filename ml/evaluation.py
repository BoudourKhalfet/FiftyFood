"""
FiftyFood - Evaluation Metrics & Utilities Module
Walk-forward CV, calibration, baselines, ablation, failure analysis.
"""

import numpy as np
import pandas as pd
from sklearn.model_selection import TimeSeriesSplit
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix, classification_report,
    mean_absolute_error, r2_score
)


def print_warning_box(text):
    """Print a warning message in a bordered box."""
    border = "=" * 70
    print(f"\n{border}")
    print(str(text))
    print(f"{border}\n")


def data_sufficiency_gate(n_samples, n_classes=3, n_features=10, min_total=50):
    """
    Check if we have enough data to train a reliable classifier.
    
    Returns: (is_sufficient, confidence_level, min_needed)
    """
    is_sufficient = n_samples >= min_total and n_samples >= n_classes * 20
    if n_samples < min_total:
        confidence = 'low'
    elif n_samples < n_classes * 25:
        confidence = 'low'
    else:
        confidence = 'reliable'
    return is_sufficient, confidence, min_total


def compute_ece(y_true, y_prob, n_bins=10):
    """
    Compute Expected Calibration Error (ECE).
    
    ECE measures how well predicted probabilities match actual outcomes.
    Lower is better. ECE < 0.1 is generally acceptable.
    """
    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    ece = 0.0
    for i in range(n_bins):
        bin_lower, bin_upper = bin_boundaries[i], bin_boundaries[i + 1]
        in_bin = (y_prob > bin_lower) & (y_prob <= bin_upper)
        prop_in_bin = in_bin.mean()
        if prop_in_bin > 0:
            avg_confidence = y_prob[in_bin].mean()
            avg_accuracy = y_true[in_bin].mean()
            ece += np.abs(avg_accuracy - avg_confidence) * prop_in_bin
    return ece


def compute_confidence_metrics(probs, y_true, model_name):
    """
    Compute confidence distribution metrics for a classifier.
    
    - Probability margin: |p - 0.5| (higher = more confident)
    - Entropy: uncertainty measure
    - Accuracy by confidence level (high/med/low)
    """
    prob_margin = np.abs(probs - 0.5)
    eps = 1e-10
    entropy = -(probs * np.log(probs + eps) + (1 - probs) * np.log(1 - probs + eps))
    
    high_conf = prob_margin > 0.4       # p < 0.1 or p > 0.9
    med_conf = (prob_margin > 0.2) & (~high_conf)  # 0.3 < p < 0.7
    low_conf = prob_margin <= 0.2        # 0.4 < p < 0.6
    
    def safe_acc(mask):
        if mask.sum() == 0:
            return np.nan
        preds = (probs[mask] > 0.5).astype(int)
        return accuracy_score(y_true[mask], preds)
    
    return {
        'model': model_name,
        'mean_margin': prob_margin.mean(),
        'mean_entropy': entropy.mean(),
        'high_conf_pct': high_conf.mean(),
        'med_conf_pct': med_conf.mean(),
        'low_conf_pct': low_conf.mean(),
        'high_conf_acc': safe_acc(high_conf),
        'med_conf_acc': safe_acc(med_conf),
        'low_conf_acc': safe_acc(low_conf),
    }


def walk_forward_cv(X, y, model, min_train=60, step=20, n_splits=None, scale=True):
    """
    Walk-forward cross-validation for time-series data.
    
    Unlike standard K-Fold, this respects temporal order:
    - Train on [0:t], test on [t:t+step]
    - Slide forward by `step` samples each fold
    
    Args:
        X: feature matrix (already sorted chronologically)
        y: target vector
        model: unfitted sklearn estimator
        min_train: minimum training samples for first fold
        step: number of samples to advance each fold
        n_splits: number of folds (auto-calculated if None)
        scale: whether to apply StandardScaler within each fold
    
    Returns list of dicts with fold metrics.
    """
    results = []
    n = len(X)
    
    if n_splits is None:
        n_splits = max(1, (n - min_train) // step)
    
    for fold in range(n_splits):
        train_end = min_train + fold * step
        test_start = train_end
        test_end = min(test_start + step, n)
        
        if test_end > n or test_start >= test_end:
            break
        
        X_tr, X_te = X[:train_end], X[test_start:test_end]
        y_tr, y_te = y[:train_end], y[test_start:test_end]
        
        if scale:
            sc = StandardScaler()
            X_tr_s = sc.fit_transform(X_tr)
            X_te_s = sc.transform(X_te)
        else:
            X_tr_s, X_te_s = X_tr, X_te
        
        model_clone = clone_if_possible(model)
        model_clone.fit(X_tr_s, y_tr)
        
        y_pred = model_clone.predict(X_te_s)
        
        if hasattr(model_clone, 'predict_proba'):
            y_prob = model_clone.predict_proba(X_te_s)[:, 1]
        else:
            y_prob = np.zeros(len(y_te))
        
        f1_m = f1_score(y_te, y_pred, average='macro', zero_division=0)
        auc = roc_auc_score(y_te, y_prob, multi_class='ovr') if len(np.unique(y_te)) > 1 else np.nan
        acc = accuracy_score(y_te, y_pred)
        
        results.append({
            'fold': fold,
            'f1_macro': f1_m,
            'roc_auc': auc,
            'accuracy': acc,
            'train_size': len(y_tr),
            'test_size': len(y_te),
        })
    
    return results


def clone_if_possible(model):
    """Try to clone model; fall back to re-instantiating if clone fails."""
    try:
        from sklearn.base import clone
        return clone(model)
    except Exception:
        # Return same model (will overwrite fit)
        return model


def evaluate_classifier(name, y_true, y_pred, y_prob):
    """Evaluate a single classifier and return metrics dict."""
    ece = compute_ece(y_true, y_prob)
    return {
        'Model': name,
        'Accuracy': round(accuracy_score(y_true, y_pred), 3),
        'Precision': round(precision_score(y_true, y_pred, zero_division=0), 3),
        'Recall': round(recall_score(y_true, y_pred, zero_division=0), 3),
        'F1-Score': round(f1_score(y_true, y_pred, zero_division=0), 3),
        'ROC-AUC': round(roc_auc_score(y_true, y_prob), 3),
        'ECE': round(ece, 3),
        'Calibration': 'OK' if ece < 0.1 else 'NEEDED',
    }


def create_baseline_predictions(df_train, df_test, cat_stats, y_test):
    """
    Create three baseline predictions for comparison:
      1. Always predict majority class
      2. Predict using category average expiration rate
      3. Simple heuristic: high price + high qty → expire
    
    Returns dict of {name: predictions_array}
    """
    global_rate = df_train['expired'].mean()
    majority_class = 1 if global_rate > 0.5 else 0
    baseline_majority = np.full_like(y_test, majority_class)
    
    cat_expired_rates = df_train.groupby('offer_type')['expired'].mean()
    
    def predict_category(row):
        rate = cat_expired_rates.get(row['offer_type'], global_rate)
        return 1 if rate > 0.5 else 0
    
    baseline_category = df_test.apply(predict_category, axis=1).values
    
    def heuristic_baseline(row):
        price_factor = row['price'] / df_train['price'].median()
        qty_factor = row['quantity'] / df_train['quantity'].median()
        return 1 if (price_factor > 1.2 and qty_factor > 1.2) else 0
    
    baseline_heuristic = df_test.apply(heuristic_baseline, axis=1).values
    
    return {
        'Always Majority': baseline_majority,
        'Category Average': baseline_category,
        'Price+Qty Heuristic': baseline_heuristic,
    }


def ablation_experiment(X, y, feature_names, model_builder, ablation_groups):
    """
    Test model performance when removing feature groups.
    
    Args:
        X: full feature matrix
        y: target
        feature_names: list of feature names (aligned with X columns)
        model_builder: function returning unfitted model
        ablation_groups: dict {group_name: [features_to_remove]}
    
    Returns dict with results for each configuration.
    """
    results = {}
    
    # Full model
    model_full = model_builder()
    model_full.fit(X, y)
    baseline_f1 = f1_score(y, model_full.predict(X), zero_division=0)
    results['full_model'] = {'f1': baseline_f1, 'features': len(feature_names)}
    
    for group_name, features_to_remove in ablation_groups.items():
        indices_to_keep = [
            i for i, name in enumerate(feature_names)
            if name not in features_to_remove
        ]
        X_ablated = X[:, indices_to_keep]
        
        model_abl = model_builder()
        model_abl.fit(X_ablated, y)
        ablated_f1 = f1_score(y, model_abl.predict(X_ablated), zero_division=0)
        
        results[group_name] = {
            'f1': ablated_f1,
            'features': len(indices_to_keep),
            'drop': baseline_f1 - ablated_f1,
        }
    
    return results


def analyze_failures(y_true, y_pred_lr, y_pred_rf, y_prob_lr, y_prob_rf,
                     df_test, cat_stats, df_train):
    """
    Analyze cases where both models fail.
    
    Returns dict with failure indices, sample cases, and pattern analysis.
    """
    lr_correct = (y_pred_lr == y_true)
    rf_correct = (y_pred_rf == y_true)
    both_failed = ~lr_correct & ~rf_correct
    failed_indices = np.where(both_failed)[0]
    
    sample_failures = failed_indices[:5]
    failure_cases = []
    
    for idx in sample_failures:
        row = df_test.iloc[idx]
        causes = []
        if row['price'] > df_train['price'].quantile(0.9):
            causes.append('Very high price (top 10%)')
        if row['quantity'] > df_train['quantity'].quantile(0.9):
            causes.append('Very high quantity (top 10%)')
        if abs(row['_demand_factor'] - 1.0) > 0.3:
            causes.append(f'Extreme latent demand ({row["_demand_factor"]:.2f})')
        if row['offer_type'] in cat_stats.index:
            if cat_stats.loc[row['offer_type'], '_count'] < 10:
                causes.append('Rare category')
        
        failure_cases.append({
            'idx': int(idx),
            'offer_type': row['offer_type'],
            'quantity': int(row['quantity']),
            'price': float(row['price']),
            'actual': 'EXPIRED' if row['expired'] else 'SOLD',
            'lr_pred': 'EXPIRED' if y_pred_lr[idx] else 'SOLD',
            'rf_pred': 'EXPIRED' if y_pred_rf[idx] else 'SOLD',
            'lr_prob': float(y_prob_lr[idx]),
            'rf_prob': float(y_prob_rf[idx]),
            'causes': causes,
        })
    
    return {
        'total_failed': int(both_failed.sum()),
        'failure_rate': float(both_failed.mean()),
        'sample_cases': failure_cases,
        'failed_indices': failed_indices.tolist(),
    }