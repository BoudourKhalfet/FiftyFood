"""
FiftyFood - Feature Engineering Module
Builds feature matrices for expiration risk and velocity classification.
"""

import pandas as pd
import numpy as np
from sklearn.preprocessing import LabelEncoder


def build_category_stats(df_train):
    """
    Compute behavioral statistics per category from training data.
    
    Returns DataFrame with columns:
      - cat_sell_rate: historical sell-through rate (1 - expiration rate)
      - cat_avg_sell_time: mean sell time in minutes
      - cat_avg_quantity: mean quantity posted
      - _count: number of offers in category
    """
    stats = df_train.groupby('offer_type').agg(
        cat_sell_rate=('expired', lambda x: 1 - x.mean()),
        cat_avg_sell_time=('sell_time_minutes', 'mean'),
        cat_avg_quantity=('quantity', 'mean'),
        _count=('offer_id', 'count')
    ).fillna(0)
    return stats


def build_expiration_features(df, cat_stats):
    """
    Build feature matrix for expiration risk classification.
    
    Features:
      - dow_0..dow_6: day-of-week one-hot encoded
      - quantity, price, publish_hour: raw offer attributes
      - cat_sell_rate, cat_avg_sell_time, cat_avg_quantity: derived category stats
    
    Note: Category names are NEVER used directly — only their behavioral stats.
    
    Returns: (X, y, feature_names)
    """
    # Day-of-week dummies
    dow_dummies = pd.get_dummies(df['day_of_week'], prefix='dow')
    dow_dummies = dow_dummies.reindex(columns=[f'dow_{i}' for i in range(7)], fill_value=0)
    
    # Join category stats
    df_cat = df.join(cat_stats, on='offer_type', how='left')
    fill_values = {
        'cat_sell_rate': cat_stats['cat_sell_rate'].mean(),
        'cat_avg_sell_time': cat_stats['cat_avg_sell_time'].mean(),
        'cat_avg_quantity': cat_stats['cat_avg_quantity'].mean()
    }
    
    df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']] = \
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].fillna(fill_values)
    
    features_df = pd.concat([
        dow_dummies.reset_index(drop=True),
        df[['quantity', 'price', 'publish_hour']].reset_index(drop=True),
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].reset_index(drop=True),
    ], axis=1)
    
    # Leakage prevention checks
    cols_list = features_df.columns.tolist()
    assert 'sell_time_minutes' not in cols_list, "LEAKAGE: sell_time_minutes in features!"
    assert 'expired' not in cols_list, "LEAKAGE: expired in features!"
    assert 'pickup_hour' not in cols_list, "LEAKAGE: pickup_hour in features!"
    
    y = df['expired'].values
    return features_df.values, y, cols_list


def build_velocity_features(df, cat_stats):
    """
    Build feature matrix for velocity classification (fast/medium/slow).
    
    Same features as expiration model. Target is velocity_class.
    
    LEAKAGE PREVENTION: These columns must NEVER be included:
      - sell_time_minutes: directly determines target
      - expired: used to assign 'slow' class
      - pickup_hour: only known after sale
    
    Returns: (X, y_encoded, classes, feature_names)
    """
    dow_dummies = pd.get_dummies(df['day_of_week'], prefix='dow')
    dow_dummies = dow_dummies.reindex(columns=[f'dow_{i}' for i in range(7)], fill_value=0)
    
    df_cat = df.join(cat_stats, on='offer_type', how='left')
    # Fill missing category stats with global category averages (same logic as expiration features)
    fill_values = {
        'cat_sell_rate': cat_stats['cat_sell_rate'].mean(),
        'cat_avg_sell_time': cat_stats['cat_avg_sell_time'].mean(),
        'cat_avg_quantity': cat_stats['cat_avg_quantity'].mean()
    }

    df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']] = \
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].fillna(fill_values)
    
    features_df = pd.concat([
        dow_dummies.reset_index(drop=True),
        df[['quantity', 'price', 'publish_hour']].reset_index(drop=True),
        df_cat[['cat_sell_rate', 'cat_avg_sell_time', 'cat_avg_quantity']].reset_index(drop=True),
    ], axis=1)
    
    cols_list = features_df.columns.tolist()
    assert 'sell_time_minutes' not in cols_list, "LEAKAGE: sell_time_minutes!"
    assert 'expired' not in cols_list, "LEAKAGE: expired!"
    assert 'pickup_hour' not in cols_list, "LEAKAGE: pickup_hour!"
    
    le = LabelEncoder()
    y_encoded = le.fit_transform(df['velocity_class'])
    
    return features_df.values, y_encoded, le.classes_, cols_list


def sell_time_to_class(sell_time, fast_thresh=15, slow_thresh=120):
    """Convert continuous sell time to discrete velocity class."""
    if sell_time < fast_thresh:
        return 'fast'
    elif sell_time > slow_thresh:
        return 'slow'
    else:
        return 'medium'