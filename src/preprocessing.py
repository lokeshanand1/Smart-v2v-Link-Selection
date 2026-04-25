import pandas as pd
from sklearn.model_selection import train_test_split

def load_and_preprocess_data(filepath, use_zero_indexed_target=False):
    """
    Loads dataset, drops NaNs in target, and splits into features/targets.
    
    Args:
        filepath (str): Path to CSV file
        use_zero_indexed_target (bool): If True, shifts link_label from 1,2,3 to 0,1,2 (needed for XGBoost, MLP)
        
    Returns:
        X, y: Features and target series
    """
    df = pd.read_csv(filepath)
    
    # Target (1 = RF, 2 = VLC, 3 = Hybrid)
    target = 'link_label'
    df[target] = pd.to_numeric(df[target], errors='coerce')
    df.dropna(subset=[target], inplace=True)
    
    # We use these core features as defined in the original script
    features = ['distance', 'speed', 'relative_speed', 'vehicle_density', 
                'fog_beta', 'rain_rate', 'LOS', 'weather_class']
    
    # If a column doesn't exist (some models used 7 features without weather_class),
    # we filter it out safely.
    available_features = [f for f in features if f in df.columns]
    
    X = df[available_features]
    y = df[target].astype(int)
    
    if use_zero_indexed_target:
        y = y - 1
        
    return X, y

def get_train_test_split(X, y, test_size=0.3, random_state=42):
    """Returns train-test split."""
    return train_test_split(X, y, test_size=test_size, random_state=random_state, stratify=y)
