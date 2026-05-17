"""
FiftyFood - Visualization Module
Plotting functions for validation, calibration, feature importance, etc.
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import accuracy_score

# Color palette
GREEN = '#2ecc71'
ORANGE = '#f39c12'
RED = '#e74c3c'
BLUE = '#3498db'
PURPLE = '#9b59b6'
PINK = '#e91e90'


def setup_plot_style():
    """Configure matplotlib/seaborn style for consistent plots."""
    sns.set_style("whitegrid")
    plt.rcParams.update({
        'font.size': 11,
        'axes.titlesize': 13,
        'axes.labelsize': 12,
        'xtick.labelsize': 10,
        'ytick.labelsize': 10,
        'legend.fontsize': 10,
        'figure.titlesize': 14,
    })


def plot_validation_grid(df_offers):
    """
    Plot 2x2 grid validating synthetic data properties:
      1. Expiration rate by offer type
      2. Velocity distribution pie chart
      3. Pickup hour histogram
      4. Sell-time boxplot by type
    """
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle('Synthetic Offer Data Validation', fontsize=14, fontweight='bold')
    
    # 1. Expiration rate by type
    ax = axes[0, 0]
    exp_by_type = df_offers.groupby('offer_type')['expired'].mean().sort_values(ascending=False)
    colors = [GREEN if v < 0.3 else ORANGE if v < 0.5 else RED for v in exp_by_type.values]
    bars = ax.bar(exp_by_type.index, exp_by_type.values, color=colors, edgecolor='white')
    ax.set_title('Expiration Rate by Offer Type')
    ax.set_ylabel('Rate')
    ax.axhline(0.5, color=RED, linestyle='--', alpha=0.5)
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=45, ha='right')
    
    # 2. Velocity pie
    ax = axes[0, 1]
    vel_dist = df_offers['velocity_class'].value_counts()
    ax.pie(vel_dist.values, labels=vel_dist.index, autopct='%1.0f%%',
           colors=[GREEN, ORANGE, RED][:len(vel_dist)], startangle=90)
    ax.set_title('Velocity Distribution')
    
    # 3. Pickup hours
    ax = axes[1, 0]
    sold = df_offers[df_offers['expired'] == 0]
    ax.hist(sold['pickup_hour'].dropna(), bins=range(7, 23), color=GREEN, alpha=0.7)
    ax.axvline(sold['pickup_hour'].mean(), color=RED, linestyle='--',
               label=f"Mean: {sold['pickup_hour'].mean():.1f}h")
    ax.set_title('Pickup Hour (Sold Offers)')
    ax.set_xlabel('Hour')
    ax.legend()
    
    # 4. Sell time boxplot
    ax = axes[1, 1]
    types = ['BURGER', 'PIZZA', 'FINE_DINING', 'SALAD', 'BRUNCH', 'FAST_FOOD']
    data = [sold[sold['offer_type'] == t]['sell_time_minutes'].dropna().values for t in types]
    bp = ax.boxplot(data, labels=types, patch_artist=True)
    colors_b = [GREEN, BLUE, PURPLE, ORANGE, PINK, RED]
    for patch, c in zip(bp['boxes'], colors_b[:len(types)]):
        patch.set_facecolor(c)
        patch.set_alpha(0.7)
    ax.set_title('Sell Time by Type (Sold)')
    ax.set_ylabel('Minutes')
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=30, ha='right')
    
    plt.tight_layout()
    plt.savefig('offer_data_validation.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_calibration_curves(models_data, y_test):
    """
    Plot calibration curves for multiple models.
    
    models_data: list of (name, y_prob) tuples
    """
    from sklearn.calibration import calibration_curve
    
    fig, axes = plt.subplots(1, len(models_data), figsize=(5 * len(models_data), 4))
    if len(models_data) == 1:
        axes = [axes]
    
    for idx, (name, y_prob) in enumerate(models_data):
        prob_true, prob_pred = calibration_curve(y_test, y_prob, n_bins=10)
        ax = axes[idx]
        ax.plot([0, 1], [0, 1], 'k--', label='Perfect')
        ax.plot(prob_pred, prob_true, 'o-', color=PURPLE, label=name)
        ax.set_xlabel('Mean Predicted Probability')
        ax.set_ylabel('Fraction of Positives')
        ax.set_title(f'{name} Calibration')
        ax.legend()
        ax.set_xlim([0, 1])
        ax.set_ylim([0, 1])
    
    plt.tight_layout()
    plt.savefig('calibration_curves.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_feature_importance(feature_names, importances, title='Feature Importance'):
    """Plot horizontal bar chart of feature importances."""
    indices = np.argsort(importances)[::-1]
    fig, ax = plt.subplots(figsize=(10, max(5, len(feature_names) * 0.3)))
    
    ax.barh(range(len(importances)), importances[indices], color=PURPLE, alpha=0.8)
    ax.set_yticks(range(len(importances)))
    ax.set_yticklabels([feature_names[i] for i in indices])
    ax.set_xlabel('Importance')
    ax.set_title(title)
    
    plt.tight_layout()
    plt.savefig('feature_importance.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_confidence_analysis(lr_probs, rf_probs, y_test):
    """Plot confidence distribution and accuracy vs confidence."""
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))
    
    # Distribution
    ax = axes[0]
    ax.hist(lr_probs, bins=30, alpha=0.5, label='LR', color=BLUE)
    ax.hist(rf_probs, bins=30, alpha=0.5, label='RF', color=GREEN)
    ax.axvline(0.5, color=RED, linestyle='--')
    ax.axvspan(0.3, 0.7, alpha=0.2, color=RED, label='Low confidence')
    ax.set_xlabel('Predicted Probability')
    ax.set_title('Confidence Distribution')
    ax.legend()
    
    # Accuracy vs margin
    ax = axes[1]
    margins_lr = np.abs(lr_probs - 0.5)
    bins = np.linspace(0, 0.5, 11)
    centers = (bins[:-1] + bins[1:]) / 2
    
    accs = []
    for i in range(len(bins) - 1):
        mask = (margins_lr >= bins[i]) & (margins_lr < bins[i + 1])
        if mask.sum() > 5:
            accs.append(accuracy_score(y_test[mask], (lr_probs[mask] > 0.5).astype(int)))
        else:
            accs.append(np.nan)
    
    ax.plot(centers, accs, 'o-', color=BLUE)
    ax.set_xlabel('|p - 0.5| (margin)')
    ax.set_ylabel('Accuracy')
    ax.set_title('Accuracy vs Confidence')
    ax.grid(True)
    
    plt.tight_layout()
    plt.savefig('confidence_analysis.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_ablation_results(results_dict, baseline_f1):
    """Plot ablation study results as horizontal bar chart."""
    names = ['Full Model']
    scores = [baseline_f1]
    colors = [GREEN]
    
    for name, res in results_dict.items():
        if name != 'full_model':
            names.append(name.replace('remove_', '- '))
            scores.append(res['f1'])
            drop = res['drop']
            if drop > 0.1:
                colors.append(RED)
            elif drop > 0.05:
                colors.append(ORANGE)
            else:
                colors.append(BLUE)
    
    fig, ax = plt.subplots(figsize=(10, max(5, len(names) * 0.4)))
    y_pos = np.arange(len(names))
    ax.barh(y_pos, scores, color=colors, alpha=0.8, edgecolor='white')
    ax.set_yticks(y_pos)
    ax.set_yticklabels(names)
    ax.set_xlabel('F1-Score')
    ax.set_title('Feature Ablation Study')
    ax.axvline(baseline_f1, color=RED, linestyle='--', linewidth=2)
    
    for bar, score in zip(ax.patches, scores):
        ax.text(bar.get_width() + 0.01, bar.get_y() + bar.get_height() / 2,
                f'{score:.3f}', va='center', fontsize=9)
    
    plt.tight_layout()
    plt.savefig('feature_ablation.png', dpi=150, bbox_inches='tight')
    plt.show()


def plot_learning_curves(sample_sizes, lr_scores, rf_scores, vel_scores=None):
    """Plot learning curves for expiration and velocity models."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    # Expiration
    ax = axes[0]
    ax.plot(sample_sizes[:len(lr_scores)], lr_scores, 'o-', label='Logistic Regression', color=BLUE)
    ax.plot(sample_sizes[:len(rf_scores)], rf_scores, 's-', label='Random Forest', color=GREEN)
    ax.axhline(0.70, color=GREEN, linestyle='--', alpha=0.5, label='Target F1=0.70')
    ax.axvline(120, color=ORANGE, linestyle='--', alpha=0.5, label='Current unlock')
    ax.set_xlabel('Training Samples')
    ax.set_ylabel('Validation F1')
    ax.set_title('Expiration Classifier Learning Curve')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Velocity
    if vel_scores is not None:
        ax = axes[1]
        ax.plot(sample_sizes[:len(vel_scores)], vel_scores, 'o-', color=PURPLE)
        ax.axhline(0.5, color=GREEN, linestyle='--', alpha=0.5, label='Target R²=0.50')
        ax.axvline(120, color=ORANGE, linestyle='--', alpha=0.5, label='Current unlock')
        ax.set_xlabel('Training Samples')
        ax.set_ylabel('Validation R²')
        ax.set_title('Velocity Regressor Learning Curve')
        ax.legend()
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig('learning_curves.png', dpi=150, bbox_inches='tight')
    plt.show()