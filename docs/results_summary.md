# Results Summary

This document summarizes the key findings and visualizations derived from the Machine Learning evaluations of the RF-VLC Hybrid system.

## 1. Network Capacity (Throughput)
- **Finding:** The Hybrid link achieves the highest overall throughput (~74.5M packets/s).
- **Interpretation:** By dynamically aggregating both RF and VLC channels when the environment is clear and the distance is short, the system successfully processes significantly more data than either standalone link could manage on its own.

## 2. Delay vs. Distance
- **Finding:** At longer distances, VLC experiences massive latency spikes.
- **Interpretation:** As inter-vehicle distance increases beyond 50-70 meters, the light signal degrades heavily. The Hybrid routing algorithm perfectly tracks the RF link's latency curve at longer distances, proving that it smartly routes traffic away from the failing VLC channel to prevent dangerous delays.

## 3. Link Selection Probability
- **Finding:** The Hybrid link is selected >50% of the time overall.
- **Interpretation:** Under normal conditions, the system defaults to Hybrid to maximize bandwidth. As weather conditions worsen (increased fog $\beta$ or rain rate), the probability of selecting RF increases sharply, demonstrating the system's fail-safe behavior.

## 4. Utility vs. Weather
- **Finding:** Hybrid consistently provides the highest utility reward across all weather classes.
- **Interpretation:** Even as fog thickens or rain intensifies, the dynamic routing engine ensures that the overall system utility (a combined metric of capacity, delay, and outage) is maximized. While VLC utility plummets in fog, the system seamlessly transitions to RF, maintaining a high baseline utility.

## 5. Model Performance Comparison
| Model | Accuracy | Precision | Recall | F1-Score |
|---|---|---|---|---|
| **Random Forest** | 89.4% | High | High | High |
| **XGBoost** | 88.7% | High | High | High |
| **Hybrid (RF+XGB)** | **89.5%** | **Highest** | **Highest** | **Highest** |

The Hybrid (RF+XGBoost) approach, utilizing a distance-based threshold strategy, slightly outperforms standalone models by capitalizing on RF's strength in short-range localized feature variance and XGBoost's robustness in long-range gradient degradation.
