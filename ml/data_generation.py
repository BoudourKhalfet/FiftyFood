"""
FiftyFood - Synthetic Data Generation Module
Generates realistic offer-level data for food rescue platform evaluation.
"""

import numpy as np
import pandas as pd
from datetime import datetime, timedelta

# Base sell-through rates by category (assumed values)
BASE_SELL_RATES = {
    'BURGER': 0.75, 'PIZZA': 0.70, 'SUSHI': 0.65, 'SALAD': 0.80,
    'PASTA': 0.60, 'TACO': 0.72, 'SANDWICH': 0.78, 'CURRY': 0.55,
    'BBQ': 0.68, 'SOUP': 0.82, 'DESSERT': 0.85, 'BREAKFAST': 0.77,
    'FINE_DINING': 0.50, 'FAST_FOOD': 0.83, 'VEGAN': 0.76, 'BRUNCH': 0.74,
    'GRILL': 0.70, 'CAFE': 0.79, 'BAKERY': 0.86, 'SEAFOOD': 0.62
}

def sell_time_to_class(sell_time, fast_thresh=15, slow_thresh=120):
    """Convert sell time (minutes) to velocity class."""
    if sell_time < fast_thresh:
        return 'fast'
    elif sell_time > slow_thresh:
        return 'slow'
    else:
        return 'medium'


def generate_train_data(n_offers=500, seed=42):
    """Generate training dataset with realistic patterns."""
    rng = np.random.default_rng(seed)
    offers = []
    start_date = pd.Timestamp('2024-01-01')
    
    for i in range(n_offers):
        offer_id = f"O{i+1:05d}"
        offer_type = rng.choice(list(BASE_SELL_RATES.keys()))
        
        # Hidden demand factor (latent variable)
        demand_factor = rng.normal(0.2, 0.1)
        demand_factor = np.clip(demand_factor, 0.5, 2.0)
        
        day_of_week = rng.integers(0, 7)
        
        # Publish hour varies by food type
        if offer_type in ['BREAKFAST', 'BRUNCH', 'CAFE']:
            publish_hour = int(rng.integers(6, 11))
        elif offer_type in ['LUNCH', 'SANDWICH', 'SALAD', 'FAST_FOOD']:
            publish_hour = int(rng.integers(10, 15))
        elif offer_type in ['DINNER', 'GRILL', 'BBQ']:
            publish_hour = int(rng.integers(16, 21))
        else:
            publish_hour = int(rng.integers(10, 20))
        
        base_quantity = int(rng.integers(5, 25))
        base_price = float(rng.uniform(3.0, 15.0))
        
        # Occasional outliers
        if rng.random() < 0.03:
            base_quantity = int(rng.integers(30, 60))
        if rng.random() < 0.02:
            base_price = float(rng.uniform(20.0, 35.0))
        
        quantity = int(base_quantity * rng.uniform(0.8, 1.2))
        price = round(base_price * rng.uniform(0.9, 1.1), 2)
        
        # Determine if sold or expired based on sell rate
        base_sell_rate = BASE_SELL_RATES.get(offer_type, 0.70)
        # 1. Price Penalty (High price = harder to sell)
        price_penalty = (price - 5.0) / 30.0 
        
        # 2. Quantity Penalty (More bags = harder to sell all of them)
        quantity_penalty = (quantity - 5) * 0.02
        
        # 3. Hour Penalty (Late night posts = less time to sell)
        hour_penalty = 0.15 if publish_hour >= 20 else 0.0
        
        # Calculate final rate
        effective_sell_rate = (base_sell_rate * demand_factor) - price_penalty - quantity_penalty - hour_penalty
        
        # Safety clip
        effective_sell_rate = float(np.clip(effective_sell_rate, 0.05, 0.98))
        # --- NEW LOGIC END ---

        if rng.random() < effective_sell_rate:
            # Sold out
            sell_time_minutes = float(rng.gamma(shape=2, scale=15) + rng.uniform(-5, 5))
            sell_time_minutes = max(1.0, sell_time_minutes)
            expired = 0
            pickup_hour = int(np.clip(publish_hour + rng.integers(0, 8), 7, 22))
        else:
            # Expired unsold
            sell_time_minutes = float(rng.gamma(shape=3, scale=25) + rng.uniform(0, 30))
            sell_time_minutes = max(10.0, sell_time_minutes)
            expired = 1
            pickup_hour = np.nan
        
        velocity_class = sell_time_to_class(sell_time_minutes)
        date = start_date + timedelta(days=i % 90)
        
        offers.append({
            'offer_id': offer_id,
            'offer_type': offer_type,
            'publish_hour': publish_hour,
            'quantity': quantity,
            'price': price,
            'day_of_week': day_of_week,
            'sell_time_minutes': sell_time_minutes,
            'expired': expired,
            'pickup_hour': pickup_hour,
            'velocity_class': velocity_class,
            'date': date,
            '_demand_factor': demand_factor,
        })
    
    df = pd.DataFrame(offers)
    
    # Add label noise (5% flip)
    flip_mask = rng.random(len(df)) < 0.05
    df.loc[flip_mask, 'expired'] = 1 - df.loc[flip_mask, 'expired']
    
    # Recompute velocity class after noise
    df['velocity_class'] = df.apply(
        lambda r: sell_time_to_class(r['sell_time_minutes']) if pd.notna(r['sell_time_minutes']) else 'slow',
        axis=1
    )
    df['day_name'] = df['date'].dt.day_name()
    
    return df


def generate_test_data(n_offers=200, seed=99, scenario='normal'):
    """Generate test dataset with optional stress scenarios."""
    rng = np.random.default_rng(seed)
    offers = []
    start_date = pd.Timestamp('2024-04-01')
    
    # Scenario modifiers
    if scenario == 'normal':
        demand_mult, price_mult, qty_mult = 1.0, 1.0, 1.0
    elif scenario == 'demand_collapse':
        demand_mult, price_mult, qty_mult = 0.7, 1.0, 1.0
    elif scenario == 'overpricing':
        demand_mult, price_mult, qty_mult = 1.0, 1.25, 1.0
    elif scenario == 'overproduction':
        demand_mult, price_mult, qty_mult = 1.0, 1.0, 2.0
    else:
        demand_mult, price_mult, qty_mult = 1.0, 1.0, 1.0
    
    for i in range(n_offers):
        offer_id = f"T{i+1:05d}"
        offer_type = rng.choice(list(BASE_SELL_RATES.keys()))
        
        demand_factor = rng.normal(1.0, 0.2) * demand_mult
        demand_factor = np.clip(demand_factor, 0.5, 2.0)
        
        day_of_week = int(rng.integers(0, 7))
        
        if offer_type in ['BREAKFAST', 'BRUNCH', 'CAFE']:
            publish_hour = int(rng.integers(6, 11))
        elif offer_type in ['LUNCH', 'SANDWICH', 'SALAD', 'FAST_FOOD']:
            publish_hour = int(rng.integers(10, 15))
        elif offer_type in ['DINNER', 'GRILL', 'BBQ']:
            publish_hour = int(rng.integers(16, 21))
        else:
            publish_hour = int(rng.integers(10, 20))
        
        base_quantity = int(rng.integers(5, 25))
        base_price = float(rng.uniform(3.0, 15.0))
        
        quantity = int(base_quantity * qty_mult * rng.uniform(0.8, 1.2))
        price = round(base_price * price_mult * rng.uniform(0.9, 1.1), 2)
        
        base_sell_rate = BASE_SELL_RATES.get(offer_type, 0.70)
        price_penalty = (price - 5.0) / 30.0 
        quantity_penalty = (quantity - 5) * 0.02
        hour_penalty = 0.15 if publish_hour >= 20 else 0.0
        
        effective_sell_rate = (base_sell_rate * demand_factor) - price_penalty - quantity_penalty - hour_penalty
        effective_sell_rate = float(np.clip(effective_sell_rate, 0.05, 0.98))
        # --- NEW LOGIC END ---

        if rng.random() < effective_sell_rate:
            sell_time_minutes = float(rng.gamma(shape=2, scale=15) + rng.uniform(-5, 5))
            sell_time_minutes = max(1.0, sell_time_minutes)
            expired = 0
            pickup_hour = int(np.clip(publish_hour + rng.integers(0, 8), 7, 22))
        else:
            sell_time_minutes = float(rng.gamma(shape=3, scale=25) + rng.uniform(0, 30))
            sell_time_minutes = max(10.0, sell_time_minutes)
            expired = 1
            pickup_hour = np.nan
        
        velocity_class = sell_time_to_class(sell_time_minutes)
        date = start_date + timedelta(days=i % 60)
        
        offers.append({
            'offer_id': offer_id,
            'offer_type': offer_type,
            'publish_hour': publish_hour,
            'quantity': quantity,
            'price': price,
            'day_of_week': day_of_week,
            'sell_time_minutes': sell_time_minutes,
            'expired': expired,
            'pickup_hour': pickup_hour,
            'velocity_class': velocity_class,
            'date': date,
            '_demand_factor': demand_factor,
        })
    
    df = pd.DataFrame(offers)
    df['day_name'] = df['date'].dt.day_name()
    return df


def generate_offer_history_test(n_offers=200, seed=99, scenario='normal'):
    """Alias for generate_test_data (for backward compatibility)."""
    return generate_test_data(n_offers=n_offers, seed=seed, scenario=scenario)