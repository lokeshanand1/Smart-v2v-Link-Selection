import matplotlib.pyplot as plt
import seaborn as sns
import joblib
import os

def set_plot_style():
    """Sets the default matplotlib and seaborn styling."""
    sns.set_theme(style="whitegrid", palette="muted")
    plt.rcParams.update({'figure.figsize': (10, 6)})

def save_model(model, filepath):
    """Saves a model to disk using joblib."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    joblib.dump(model, filepath)
    print(f"Model saved to {filepath}")

def load_model(filepath):
    """Loads a model from disk using joblib."""
    if os.path.exists(filepath):
        return joblib.load(filepath)
    else:
        raise FileNotFoundError(f"No model found at {filepath}")
