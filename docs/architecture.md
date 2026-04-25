# System Architecture

## Overview
The RF-VLC Hybrid V2V System is designed to dynamically adapt vehicular communication links based on physical and environmental contexts.

## Pipeline Breakdown

1. **Data Ingestion**
   - **Inputs:** Distance (m), Speed (km/h), Vehicle Density, Fog Density ($\beta$), Rain Rate (mm/hr), and Line of Sight (LOS) indicator.
   - **Source:** Simulated datasets mapped to realistic physical models (generated via MATLAB).

2. **Feature Engineering**
   - Normalization of distance, speed, and density.
   - Derivation of `weather_combined` metric ($\text{fog\_beta} + \text{rain\_rate} / 50$).
   - Calculation of individual proxy scores for RF Quality, VLC Quality, Delay, and Outage factors.

3. **Intelligent Routing Engine**
   - The core decision engine uses an ensemble of Machine Learning models.
   - **Short-Distance Router:** A Random Forest classifier optimized for high-variance, short-range dynamics (e.g., sudden braking, immediate LOS blockage).
   - **Long-Distance Router:** An XGBoost classifier tuned to handle gradual signal degradation, severe weather, and longer propagation delays.
   - **Threshold Logic:** The system uses a predefined threshold (e.g., 75m) to switch inference requests between the RF and XGBoost sub-models to maximize accuracy and minimize inference latency.

4. **Link Actuation (Simulation Output)**
   - **Link 1 (RF):** Selected when VLC is completely degraded by fog/rain or when the vehicle is out of VLC range.
   - **Link 2 (VLC):** Selected for high-bandwidth data transfer in clear weather and close proximity.
   - **Link 3 (Hybrid):** Selected when both links are viable, aggregating bandwidth to achieve maximum throughput.

## Technologies Used
- **MATLAB:** Physical layer simulation and dataset generation.
- **Python (Scikit-Learn, XGBoost):** Machine Learning pipeline, model training, and evaluation.
- **Streamlit:** Interactive web interface for real-time model inference and demonstration.
- **Pandas, NumPy, Seaborn:** Data manipulation and visualization.
