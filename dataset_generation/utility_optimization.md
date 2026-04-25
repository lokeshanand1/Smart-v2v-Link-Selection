# Utility Optimization

The dataset generation script formulates a multi-objective optimization problem to determine the "ground truth" optimal link (label). 

## Multi-Objective Function
For each simulated environmental state, the system computes an overall utility $U$ for all possible configurations (RF, VLC, Hybrid).

$$ U = w_1 \cdot \text{Capacity}_{norm} - w_2 \cdot \text{Delay}_{norm} - w_3 \cdot \text{Outage}_{norm} $$

## Dynamic Weighting vs Fixed Weighting
The repository contains two variations of datasets:
1. **`fixed_weight_dataset.csv`**: Uses static weights (e.g., $w_1=0.4, w_2=0.3, w_3=0.3$) across all states.
2. **`optimized_weight_dataset.csv`**: Employs a grid-search algorithm during generation to dynamically adjust weights based on the environmental severity (e.g., prioritizing low delay in dense traffic, or minimizing outage in heavy fog). This produces a much more resilient and intelligent labeling system.
