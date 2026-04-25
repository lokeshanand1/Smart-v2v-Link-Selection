# Mathematical Methodology

This document outlines the core channel models and utility optimization formulas used to generate the dataset and evaluate the intelligent V2V routing engine.

## 1. RF Path Loss and Channel Model
The RF link (simulating DSRC/C-V2X at 5.9 GHz) uses a standard log-distance path loss model:

$$ PL(d) = PL_0 + 10 \gamma \log_{10} \left( \frac{d}{d_0} \right) + X_g $$

Where:
- $PL_0$ is the reference path loss at distance $d_0$.
- $\gamma$ is the path loss exponent.
- $X_g$ represents log-normal shadow fading.
- $d$ is the inter-vehicle distance.

**Weather Attenuation for RF:** Rain causes slight attenuation ($\alpha_{rain}$), though RF is generally robust compared to VLC.

## 2. VLC Channel Model and Weather Attenuation
VLC relies on Light Emitting Diodes (LEDs) and Photodetectors (PDs). The received optical power $P_r$ is given by:

$$ P_r = P_t \times H(0) \times e^{-\beta d} $$

Where:
- $P_t$ is the transmitted optical power.
- $H(0)$ is the DC channel gain.
- $\beta$ represents the atmospheric attenuation coefficient (fog density).

**Fog Attenuation ($\beta$):** Modeled using the Kim model based on visibility ($V$):
$$ \beta = \frac{3.91}{V} \left( \frac{\lambda}{550 \text{ nm}} \right)^{-q} $$
Where $q$ depends on the visibility range. As fog density increases, $\beta$ increases drastically, causing VLC link failure.

## 3. Delay Model
Delay ($D$) comprises transmission, propagation, and processing delays. In dense traffic, queuing delay increases exponentially:

$$ D_{total} = D_{trans} + D_{prop} + D_{queue} $$
$$ D_{queue} \propto \frac{1}{\mu - \lambda_{arrival}} $$
*(Where $\lambda_{arrival}$ is influenced by vehicle density and relative speed).*

## 4. Outage Probability
Outage occurs when the Signal-to-Noise Ratio (SNR) falls below a strict threshold $\gamma_{th}$:

$$ P_{out} = P(\text{SNR} < \gamma_{th}) $$

For VLC, $P_{out}$ approaches 1.0 rapidly in fog. For RF, $P_{out}$ increases gracefully with distance.

## 5. Utility Optimization Function
The system decides the optimal link by maximizing a multi-objective utility function ($U$):

$$ U = w_1 \cdot \text{Capacity}_{norm} - w_2 \cdot \text{Delay}_{norm} - w_3 \cdot \text{Outage}_{norm} $$

Where $w_1, w_2, w_3$ are weights that can be fixed or dynamically optimized. The routing engine outputs the link (1=RF, 2=VLC, 3=Hybrid) that maximizes $U$ for the current environmental state vector.
