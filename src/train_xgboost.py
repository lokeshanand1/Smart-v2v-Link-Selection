import argparse
import os
from xgboost import XGBClassifier
from sklearn.metrics import accuracy_score, classification_report
from preprocessing import load_and_preprocess_data, get_train_test_split
from utils import save_model

def main(data_path, model_dir):
    print("Loading data for XGBoost training...")
    # XGBoost requires zero-indexed labels
    X, y = load_and_preprocess_data(data_path, use_zero_indexed_target=True)
    
    X_train, X_test, y_train, y_test = get_train_test_split(X, y)
    
    print("Training XGBoost...")
    xgb = XGBClassifier(
        n_estimators=200,
        max_depth=6,
        learning_rate=0.1,
        subsample=0.8,
        colsample_bytree=0.8,
        random_state=42,
        eval_metric='mlogloss',
        num_class=3
    )
    xgb.fit(X_train, y_train)
    
    y_pred = xgb.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"XGBoost Accuracy: {acc:.4f}")
    print("\nClassification Report:\n", classification_report(y_test, y_pred))
    
    model_path = os.path.join(model_dir, "xgboost.pkl")
    save_model(xgb, model_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train XGBoost Model")
    parser.add_argument("--data", type=str, default="../data/raw/optimized_weight_dataset.csv", help="Path to dataset")
    parser.add_argument("--model_dir", type=str, default="../models", help="Directory to save the model")
    args = parser.parse_args()
    
    main(args.data, args.model_dir)
