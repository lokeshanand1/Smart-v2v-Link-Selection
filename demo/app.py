import streamlit as st
import pandas as pd
import numpy as np
import os
import joblib

# Set page config
st.set_page_config(page_title="V2V Link Predictor", page_icon="🚗", layout="centered")

st.title("🚗 Intelligent V2V Communication Router")
st.markdown("""
This application predicts the optimal communication link (**RF, VLC, or Hybrid**) for Vehicle-to-Vehicle (V2V) networks based on real-time environmental and mobility conditions.
""")

# Input Sidebar
st.sidebar.header("📡 Real-time Telemetry Input")

distance = st.sidebar.slider("Distance (m)", min_value=5.0, max_value=200.0, value=50.0, step=1.0)
speed = st.sidebar.slider("Speed (km/h)", min_value=0.0, max_value=140.0, value=60.0, step=1.0)
fog_density = st.sidebar.slider("Fog Density (Beta)", min_value=0.0, max_value=5.0, value=0.1, step=0.1)
rain_rate = st.sidebar.slider("Rain Rate (mm/hr)", min_value=0.0, max_value=50.0, value=0.0, step=1.0)
vehicle_density = st.sidebar.slider("Vehicle Density", min_value=10, max_value=200, value=50, step=5)

# Derived / constant features for the model
relative_speed = speed * 0.1  # Simplified assumption
weather_class = 1
if fog_density > 1.5 or rain_rate > 20:
    weather_class = 4
elif fog_density > 0.5 or rain_rate > 10:
    weather_class = 3
elif fog_density > 0.1 or rain_rate > 2:
    weather_class = 2

los = 1 if weather_class < 3 else 0

st.subheader("Current Context")
col1, col2, col3 = st.columns(3)
col1.metric("Distance", f"{distance} m")
col2.metric("Fog Beta", f"{fog_density}")
col3.metric("Rain Rate", f"{rain_rate} mm/h")

# Prediction Logic
st.markdown("---")
st.subheader("🤖 AI Routing Decision")

def load_models():
    # Attempt to load trained models. If not found, show warning.
    rf_path = os.path.join(os.path.dirname(__file__), "../models/rf_short_distance.pkl")
    xgb_path = os.path.join(os.path.dirname(__file__), "../models/xgb_long_distance.pkl")
    
    if os.path.exists(rf_path) and os.path.exists(xgb_path):
        return joblib.load(rf_path), joblib.load(xgb_path)
    return None, None

rf_model, xgb_model = load_models()

if st.button("Predict Optimal Link"):
    if rf_model is None or xgb_model is None:
        st.error("⚠️ Models not found! Please run `python src/hybrid_model.py` to train and save the models first for reproducibility.")
    else:
        # Prepare input data
        input_data = pd.DataFrame({
            'distance': [distance],
            'speed': [speed],
            'relative_speed': [relative_speed],
            'vehicle_density': [vehicle_density],
            'fog_beta': [fog_density],
            'rain_rate': [rain_rate],
            'LOS': [los],
            'weather_class': [weather_class]
        })
        
        # Hybrid threshold logic
        if distance <= 75:
            # Use RF model for short distance, but inputs might need exact feature order.
            # Filtering to features used by RF
            pred = rf_model.predict(input_data)[0]
        else:
            # Use XGBoost for long distance
            features_7 = ['distance','speed','relative_speed','vehicle_density', 'fog_beta', 'rain_rate','LOS']
            pred = xgb_model.predict(input_data[features_7])[0]
        
        # Mapping 0-indexed predictions to human labels
        # 0 = RF, 1 = VLC, 2 = Hybrid
        labels = {0: "📻 Radio Frequency (RF)", 1: "💡 Visible Light (VLC)", 2: "🔗 Hybrid (RF + VLC)"}
        
        predicted_label = labels.get(pred, "Unknown")
        
        st.success(f"### Recommended Link: {predicted_label}")
        
        st.info("""
        **Why?**
        - **VLC** is preferred at short distances with clear weather due to massive bandwidth.
        - **RF** takes over during heavy fog/rain or long distances due to superior penetration.
        - **Hybrid** is selected when both channels are viable and bandwidth aggregation maximizes utility.
        """)
