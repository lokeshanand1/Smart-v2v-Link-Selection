# Mathematical Formulas

This document provides a detailed explanation of the major physical layer and optimization formulas used in the Smart V2V Link Selection framework.

## 1. RF Communication Model

### Path Loss (Log-Distance Model)
Used to predict signal degradation over distance **d**:

```math
PL = PL_0 + 10n\log_{10}(d) + X_\sigma
```

where **n** is the path loss exponent and **X_σ** represents shadowing.

### Rain Attenuation
```math
SNR_{RF\_rain} = SNR_{RF} \cdot e^{-0.06r}
```
where **r** is the rain rate in mm/hr.

### Gaseous Absorption
```math
SNR_{RF\_gas} = SNR_{RF} \cdot e^{-0.02d}
```
where **d** is distance in meters.

### Doppler Fading (Mobility Impact)
```math
SNR_{RF\_doppler} = SNR_{RF} \cdot e^{-v/100}
```
where **v** is the vehicle speed in km/h.

## 2. VLC Communication Model

### Optical Channel Gain
```math
H = \frac{(m+1)A}{2\pi d^2} \cos^m(\phi) T_s(\psi) g(\psi) \cos(\psi)
```

Simplified for simulation as:
```math
H = \frac{(m+1)A}{2\pi d^2}
```

### Fog Attenuation (Kim Model)
```math
H_{fog} = H \cdot e^{-18\beta(d/1000)}
```
where **β** is the fog attenuation coefficient.

### LOS Probability (Blockage)
```math
P_{LOS} = e^{-k \cdot \text{density} \cdot d / 1000}
```
where **k** is a scaling constant for vehicle density.

### Mobility Misalignment
```math
SNR_{VLC\_mobility} = SNR_{VLC} \cdot e^{-v/80}
```

## 3. Hybrid & Optimization

### Hybrid Capacity Aggregation
```math
C_{HYB} = 0.6 \cdot (C_{RF} + C_{VLC})
```

### Hybrid Outage Probability
```math
P_{out(HYB)} = P_{out(RF)} \cdot P_{out(VLC)}
```

### Utility Optimization Function
The objective function maximized by the system:
```math
U = w_C \cdot C - w_D \cdot D - w_O \cdot P
```
where **C** is Capacity, **D** is Delay, and **P** is Outage Probability.
