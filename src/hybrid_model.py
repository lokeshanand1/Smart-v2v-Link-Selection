import argparse
import os
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from xgboost import XGBClassifier
from sklearn.metrics import accuracy_score, classification_report
from preprocessing import load_and_preprocess_data, get_train_test_split
from utils import save_model

def hybrid_predict(X_input, rf_model, xgb_model, dist_threshold=75):
    """
    Predicts using RF for short distances and XGBoost for long distances.
    Assumes X_input is a pandas DataFrame that contains a 'distance' column.
    """
    # Use zero-indexed labels mapping (0: RF, 1: VLC, 2: Hybrid)
    short_idx = X_input['distance'] <= dist_threshold
    long_idx  = X_input['distance'] > dist_threshold

    y_pred = np.zeros(len(X_input))

    if sum(short_idx) > 0:
        y_pred[short_idx] = rf_model.predict(X_input[short_idx])

    if sum(long_idx) > 0:
        y_pred[long_idx] = xgb_model.predict(X_input[long_idx])

    return y_pred

def train_and_evaluate_hybrid(data_path, model_dir):
    print("Loading data for Hybrid Model training...")
    # Using 0-indexed for consistency across both models in the hybrid approach
    X, y = load_and_preprocess_data(data_path, use_zero_indexed_target=True)
    X_train, X_test, y_train, y_test = get_train_test_split(X, y)
    
    DIST_THRESHOLD = 75
    
    # Split train data based on distance
    train_short = X_train['distance'] <= DIST_THRESHOLD
    train_long  = X_train['distance'] > DIST_THRESHOLD
    
    X_train_short, y_train_short = X_train[train_short], y_train[train_short]
    X_train_long, y_train_long   = X_train[train_long], y_train[train_long]
    
    print("Training RF for short distance...")
    rf_model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    rf_model.fit(X_train_short, y_train_short)
    
    print("Training XGBoost for long distance...")
    xgb_model = XGBClassifier(
        n_estimators=200, max_depth=6, learning_rate=0.1, 
        subsample=0.8, colsample_bytree=0.8, random_state=42, 
        eval_metric='mlogloss', num_class=3
    )
    xgb_model.fit(X_train_long, y_train_long)
    
    print("Evaluating Hybrid Model...")
    y_pred = hybrid_predict(X_test, rf_model, xgb_model, DIST_THRESHOLD)
    
    acc = accuracy_score(y_test, y_pred)
    print(f"Hybrid Model Accuracy: {acc:.4f}")
    print("\nClassification Report:\n", classification_report(y_test, y_pred))
    
    save_model(rf_model, os.path.join(model_dir, "rf_short_distance.pkl"))
    save_model(xgb_model, os.path.join(model_dir, "xgb_long_distance.pkl"))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train Hybrid RF/XGBoost Model")
    parser.add_argument("--data", type=str, default="../data/raw/optimized_weight_dataset.csv", help="Path to dataset")
    parser.add_argument("--model_dir", type=str, default="../models", help="Directory to save the models")
    args = parser.parse_args()
    
    train_and_evaluate_hybrid(args.data, args.model_dir)
