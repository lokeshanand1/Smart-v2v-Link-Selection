# Channel Modeling

This directory contains the MATLAB script `synthetic_dataset_generator.m` which simulates the physical RF and VLC communication channels for Vehicle-to-Vehicle (V2V) environments.

## RF Channel (5.9 GHz C-V2X / DSRC)
The RF channel is modeled using a standard Log-Distance Path Loss model combined with log-normal shadowing to represent typical urban or highway scattering environments. 
- **Distance dependency:** Signal quality decreases logarithmically with distance.
- **Weather dependency:** Highly robust against fog, with minor attenuation due to heavy rain.

## VLC Channel (Visible Light Communication)
The VLC channel uses Line-of-Sight (LOS) optical propagation.
- **Distance dependency:** Exponentially degrades with distance due to optical scattering.
- **Weather dependency:** Highly susceptible to atmospheric scattering (Fog/Beta). The Kim model is utilized to calculate fog attenuation ($\beta$) based on varying visibility conditions.
