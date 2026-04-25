import argparse
import os
from sklearn.neural_network import MLPClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import accuracy_score, classification_report
from preprocessing import load_and_preprocess_data, get_train_test_split
from utils import save_model

def main(data_path, model_dir):
    print("Loading data for MLP training...")
    # MLP expects zero-indexed targets for easier interpretation, but sklearn handles any classes.
    # We will use zero-indexed for consistency with XGBoost if we want to ensemble them later.
    X, y = load_and_preprocess_data(data_path, use_zero_indexed_target=True)
    
    X_train, X_test, y_train, y_test = get_train_test_split(X, y)
    
    print("Scaling features...")
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    print("Training MLP Classifier...")
    mlp = MLPClassifier(
        hidden_layer_sizes=(128, 64, 32),
        activation='relu',
        solver='adam',
        alpha=0.0005,
        learning_rate='adaptive',
        max_iter=200,
        early_stopping=True,
        random_state=42
    )
    mlp.fit(X_train_scaled, y_train)
    
    y_pred = mlp.predict(X_test_scaled)
    acc = accuracy_score(y_test, y_pred)
    print(f"MLP Accuracy: {acc:.4f}")
    print("\nClassification Report:\n", classification_report(y_test, y_pred))
    
    model_path = os.path.join(model_dir, "mlp.pkl")
    save_model(mlp, model_path)
    
    # Also save the scaler for inference
    scaler_path = os.path.join(model_dir, "scaler.pkl")
    save_model(scaler, scaler_path)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train MLP Model")
    parser.add_argument("--data", type=str, default="../data/raw/optimized_weight_dataset.csv", help="Path to dataset")
    parser.add_argument("--model_dir", type=str, default="../models", help="Directory to save the model")
    args = parser.parse_args()
    
    main(args.data, args.model_dir)
