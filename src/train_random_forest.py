import argparse
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report
from preprocessing import load_and_preprocess_data, get_train_test_split
from utils import save_model

def main(data_path, model_dir):
    print("Loading data for Random Forest training...")
    X, y = load_and_preprocess_data(data_path, use_zero_indexed_target=False)
    
    # Optional: we can tune the threshold if needed, but here we just train on the whole set
    # as in the original monolithic script, or train it for the short distance as used in Hybrid.
    # The original script did both: one overall RF, and one RF for hybrid (short distance).
    # We'll stick to a robust RF trained on the dataset.
    
    X_train, X_test, y_train, y_test = get_train_test_split(X, y)
    
    print("Training Random Forest...")
    rf = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42,
        min_samples_split=10,
        min_samples_leaf=8,
        max_features='sqrt'
    )
    rf.fit(X_train, y_train)
    
    y_pred = rf.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    print(f"Random Forest Accuracy: {acc:.4f}")
    print("\nClassification Report:\n", classification_report(y_test, y_pred))
    
    model_path = os.path.join(model_dir, "random_forest.pkl")
    save_model(rf, model_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train Random Forest Model")
    parser.add_argument("--data", type=str, default="../data/raw/optimized_weight_dataset.csv", help="Path to dataset")
    parser.add_argument("--model_dir", type=str, default="../models", help="Directory to save the model")
    args = parser.parse_args()
    
    main(args.data, args.model_dir)
