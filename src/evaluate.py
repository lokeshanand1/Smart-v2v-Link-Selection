import argparse
import os
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
from preprocessing import load_and_preprocess_data, get_train_test_split
from hybrid_model import hybrid_predict
from utils import load_model, set_plot_style

def evaluate_models(data_path, model_dir, output_dir):
    set_plot_style()
    os.makedirs(output_dir, exist_ok=True)
    
    print("Loading data for evaluation...")
    X, y = load_and_preprocess_data(data_path, use_zero_indexed_target=True)
    _, X_test, _, y_test = get_train_test_split(X, y)
    
    print("Loading models...")
    rf_hybrid = load_model(os.path.join(model_dir, "rf_short_distance.pkl"))
    xgb_hybrid = load_model(os.path.join(model_dir, "xgb_long_distance.pkl"))
    
    # Can also load standalone RF, XGBoost, and MLP if needed, but hybrid is our main star.
    print("Evaluating Hybrid Model...")
    y_pred_hybrid = hybrid_predict(X_test, rf_hybrid, xgb_hybrid, dist_threshold=75)
    
    acc_hybrid = accuracy_score(y_test, y_pred_hybrid)
    print(f"Hybrid Model Accuracy: {acc_hybrid:.4f}")
    
    print("\nClassification Report:\n", classification_report(y_test, y_pred_hybrid))
    
    # Confusion Matrix
    cm = confusion_matrix(y_test, y_pred_hybrid)
    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', xticklabels=['RF', 'VLC', 'Hybrid'], yticklabels=['RF', 'VLC', 'Hybrid'])
    plt.xlabel("Predicted")
    plt.ylabel("Actual")
    plt.title(f"Confusion Matrix: Hybrid Model\nAccuracy: {acc_hybrid:.2%}")
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, "confusion_matrix_hybrid.png"), dpi=300)
    print(f"Saved confusion matrix to {output_dir}/confusion_matrix_hybrid.png")
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Evaluate Models and Generate Plots")
    parser.add_argument("--data", type=str, default="../data/raw/optimized_weight_dataset.csv", help="Path to dataset")
    parser.add_argument("--model_dir", type=str, default="../models", help="Directory where models are saved")
    parser.add_argument("--output_dir", type=str, default="../results/plots", help="Directory to save evaluation plots")
    args = parser.parse_args()
    
    evaluate_models(args.data, args.model_dir, args.output_dir)
