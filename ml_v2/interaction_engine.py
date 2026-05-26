"""
Feature Interaction Engine for ML v2.

Detects non-linear feature interactions for specific offers using SHAP interaction values.
"""

import numpy as np
from catboost import CatBoostClassifier, Pool

def detect_interactions(
    model: CatBoostClassifier,
    pool: Pool,
    feature_names: list[str],
    actionable_features: set[str],
    threshold: float = 0.01,
) -> list[tuple[str, str, float]]:
    """
    Detect pairs of features that interact strongly for the given offer(s).
    
    Returns:
        List of tuples (feature_a, feature_b, interaction_strength), sorted by strength descending.
    """
    # ShapInteractionValues returns shape (n_samples, n_features+1, n_features+1)
    # The last row/column corresponds to the expected value (base value).
    interactions = model.get_feature_importance(pool, type="ShapInteractionValues")
    
    if len(interactions.shape) == 3:
        # Take the first sample (we typically call this per offer)
        # or mean if batch
        interaction_matrix = np.abs(interactions[:, :-1, :-1]).mean(axis=0)
    else:
        interaction_matrix = np.abs(interactions[:-1, :-1])
        
    n_features = len(feature_names)
    detected = []
    
    for i in range(n_features):
        for j in range(i + 1, n_features):
            f1 = feature_names[i]
            f2 = feature_names[j]
            
            # We only care if at least one feature is actionable
            if f1 not in actionable_features and f2 not in actionable_features:
                continue
                
            # CatBoost SHAP interaction values are symmetric.
            # The total interaction effect is phi_ij + phi_ji = 2 * phi_ij
            strength = float(interaction_matrix[i, j]) * 2.0
            
            if strength >= threshold:
                detected.append((f1, f2, strength))
                
    detected.sort(key=lambda x: x[2], reverse=True)
    return detected
