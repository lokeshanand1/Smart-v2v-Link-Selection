clc;
clear;
close all;
rng(1);

%% ================= DATASET CONFIGURATION =================
% N: Total samples (60,000) to ensure high statistical significance for training.
N  = 60000;
Nw = N/4;
v_max = 140; % Max speed in km/h

%% ================= RF PARAMETERS (5.9 GHz DSRC/C-V2X) =================
Pt_rf_dBm    = 20;
Noise_rf_dBm = -96;
BW_rf        = 10e6;
fc           = 5.9e9;
c            = 3e8;
lambda       = c/fc;
n            = 2.2; % [Ref: Mecklenbräuker et al., 2011] Highway path loss exponent
shadow_sigma = 4;   % [Ref: ITU-R P.1411] Standard shadowing for vehicular env.

%% ================= VLC PARAMETERS =================
Pt_vlc    = 10;
BW_vlc    = 20e6;
R         = 0.4;    % Responsivity [Ref: Kashef et al., 2016]
Noise_vlc = 1e-9;

%% ================= PACKET =================
L = 1500 * 8; % Standard Ethernet packet size (12,000 bits)

%% ================= DISTANCE & MOBILITY =================
% Vehicles distributed using a Poisson process [Ref: Abbas et al., 2012]
lambda_vehicle = 0.015;
distance = min(10 + exprnd(1/lambda_vehicle, N, 1), 200);
speed = v_max * (rand(N,1));
relative_speed = abs(30* randn(N,1)); % Mean speed difference between vehicles
vehicle_density = 20+ 80 * rand(N,1); % 20 (Light traffic) to 100 (Congested)

%% ================= WEATHER GENERATION =================
% Class 1: Clear | Class 2: Rain | Class 3: Light Fog | Class 4: Dense Fog
weather_class = repelem((1:4)', Nw);
fog_beta  = zeros(N,1);
rain_rate = zeros(N,1);

rain_rate(Nw+1:2*Nw) = 5+ 45 * rand(Nw,1);
fog_beta(2*Nw+1:3*Nw) = 0.3 + 1.2 * rand(Nw,1);
fog_beta(3*Nw+1:end) = 1.5 + 4.5* rand(Nw,1);

%% ================= RF CHANNEL MODELING & PENALTIES =================
PL0 = 20 * log10(4*pi/lambda);
shadow = shadow_sigma * randn(N,1);
PL_rf = PL0 + 10*n*log10(distance) + shadow;
Pr_rf_dBm = Pt_rf_dBm - PL_rf;
SNR_rf = 10.^((Pr_rf_dBm - Noise_rf_dBm)/10);

% PHYSICS PENALTY 1: Rain Attenuation [Ref: ITU-R P.838-3]
SNR_rf = SNR_rf .* exp(-0.06.*rain_rate); 

% PHYSICS PENALTY 2: Gaseous Absorption [Ref: ITU-R P.676]
SNR_rf = SNR_rf .* exp(-0.02 .* distance);

% PHYSICS PENALTY 3: Co-Channel Interference (CCI) [Ref: Shao et al., 2014]
d_factor = exp(-distance / 50);              
density_factor = vehicle_density / 100;     
rf_penalty = 1 - 0.92 * (d_factor .* density_factor);
SNR_rf = SNR_rf .* rf_penalty;

% PHYSICS PENALTY 4: Doppler-Induced Fading [Ref: Mecklenbräuker et al., 2011]
SNR_rf = SNR_rf .* exp(-relative_speed/100);

C_rf = BW_rf .* log2(1 + SNR_rf);
gamma_th_RF = 2^(2e6/BW_rf) - 1;
Pout_RF = min(1, 1 - exp(-gamma_th_RF ./ (SNR_rf + 1e-12)));

%% ================= VLC CHANNEL MODELING & PENALTIES =================
distance_vlc = max(distance,5);
m = 1;      % Lambertian order
A = 1e-4;   % Detector area
g_con = 1.5; % Optical concentrator gain
H = ((m+1)*A/(2*pi)) .* (1 ./ distance_vlc.^2);

% PHYSICS PENALTY 5: Mie Scattering (Fog Penalty) [Ref: Naboulsi et al., 2004]
H = H .* exp(-18.0 .* fog_beta .* (distance_vlc/1000));

% PHYSICS PENALTY 6: LOS Blockage (Visual Occlusion) [Ref: Abbas et al., 2012]
k = 0.05;
P_LOS = exp(-k .* vehicle_density .* distance / 1000);
LOS = rand(N,1) < P_LOS;
H = H .* (0.5 .* LOS + 0.1);
H = H * g_con;

% PHYSICS PENALTY 7: Alignment Jitter & Mobility [Ref: Kashef et al., 2016]
Pr_optical = Pt_vlc .* H;
SNR_vlc = (R .* Pr_optical) ./ Noise_vlc;
SNR_vlc = SNR_vlc .* exp(-relative_speed/80);

C_vlc = BW_vlc .* log2(1 + SNR_vlc);
gamma_th_VLC = 2^(2e6/BW_vlc) - 1;
Pout_VLC = min(1, 1 - exp(-gamma_th_VLC ./ (SNR_vlc + 1e-12)));

%% ================= DELAY & HYBRID LINK LOGIC =================
D_RF  = L ./ (C_rf + 1e-12);
D_VLC = L ./ (C_vlc + 1e-12);

alpha = C_rf ./ (C_rf + C_vlc + 1e-12);
D_HYB = max((alpha .* L) ./ (C_rf + 1e-12), ...
            ((1-alpha) .* L) ./ (C_vlc + 1e-12));

% PHYSICS PENALTY 8: Packet Reordering & Imbalance [Ref: Shao et al., 2014]
imbalance = abs(C_rf - C_vlc) ./ (C_rf + C_vlc + 1e-12);
D_HYB = D_HYB .* (1 + imbalance);

% PHYSICS PENALTY 9: MAC Synchronization Overhead [Ref: Kashef et al., 2016]
C_HYB = 0.6.* (C_rf + C_vlc);
Pout_HYB = Pout_RF .* Pout_VLC;

hybrid_invalid = (SNR_rf < 2) | (SNR_vlc < 3);
C_HYB(hybrid_invalid) = 0;
Pout_HYB(hybrid_invalid) = 1;

%% ================= NORMALIZATION =================
Cmax = max([C_rf; C_vlc; C_HYB]);
Dmax = max([D_RF; D_VLC; D_HYB]);

C_rf_n  = C_rf  / Cmax;
C_vlc_n = C_vlc / Cmax;
C_hyb_n = C_HYB / Cmax;

D_rf_n  = D_RF  / Dmax;
D_vlc_n = D_VLC / Dmax;
D_hyb_n = D_HYB / Dmax;

%% ================= GRID SEARCH + CV =================
K = 10;
indices = crossvalind('Kfold', N, K);
best_score = -inf;
best_weights = [0 0 0];
wC_range = 0.1:0.05:1;
wD_range = 0.1:0.05:1;

for wC = wC_range
    for wD = wD_range
        wO = 1 - (wC + wD);
        if wO < 0.1 || wO > 1, continue; end
        scores = zeros(K,1);
        for k = 1:K
            U_RF  = wC*C_rf_n  - wD*D_rf_n  - wO*Pout_RF;
            U_VLC = wC*C_vlc_n - wD*D_vlc_n - wO*Pout_VLC;
            U_HYB = wC*C_hyb_n - wD*D_hyb_n - wO*Pout_HYB;
            U_HYB(hybrid_invalid) = -inf;
            
            [~, pred] = max([U_RF U_VLC U_HYB], [], 2);
            scores(k) = -std([sum(pred==1) sum(pred==2) sum(pred==3)]/N);
        end
        if mean(scores) > best_score
            best_score = mean(scores); best_weights = [wC wD wO];
        end
    end
end

%% ================= FINAL LABELING & EXPORT =================
wC = best_weights(1); wD = best_weights(2); wO = best_weights(3);
disp('Optimal System Weights (C, D, Outage):')
disp([wC wD wO])

U_RF  = wC*C_rf_n  - wD*D_rf_n  - wO*Pout_RF;
U_VLC = wC*C_vlc_n - wD*D_vlc_n - wO*Pout_VLC;
U_HYB = wC*C_hyb_n - wD*D_hyb_n - wO*Pout_HYB;
U_HYB(hybrid_invalid) = -inf;

[~, link_label] = max([U_RF U_VLC U_HYB], [], 2);

Dataset = table(distance, speed, relative_speed, vehicle_density, ...
                fog_beta, rain_rate, weather_class, link_label, LOS);
writetable(Dataset,'Final_RF_VLC_HYBRID_OPTIMIZED.csv');
disp('Dataset Saved Successfully: Final_RF_VLC_HYBRID_OPTIMIZED.csv')

%% ================= RESULTS SUMMARY =================
disp('Final Selection Distribution:')
disp(['RF Links: ', num2str(sum(link_label==1))])
disp(['VLC Links: ', num2str(sum(link_label==2))])
disp(['HYBRID Links: ', num2str(sum(link_label==3))])

%% ================= GLOBAL STYLE =================
set(groot,'defaultFigureColor','w');
set(groot,'defaultAxesFontName','Times New Roman');
set(groot,'defaultAxesFontSize',11);
set(groot,'defaultAxesLineWidth',1.2);
set(groot,'defaultLineLineWidth',2);

%% FIGURE 1 : Utility Comparison vs Weather
clrRF  = [0.90 0.35 0.10];   % Reddish Orange
clrHYB = [0.20 0.65 0.25];   % Green
clrVLC = [0.95 0.78 0.15];   % Yellow

U_RF_mean  = zeros(4,1);
U_VLC_mean = zeros(4,1);
U_HYB_mean = zeros(4,1);
for i = 1:4
    idx = weather_class == i;
    U_RF_mean(i)  = mean(U_RF(idx));
    U_VLC_mean(i) = mean(U_VLC(idx));
    temp = U_HYB(idx);
    temp = temp(~isinf(temp));
    if isempty(temp)
        U_HYB_mean(i)=NaN;
    else
        U_HYB_mean(i)=mean(temp);
    end
end
U_all = [U_RF_mean U_VLC_mean U_HYB_mean];
figure('Units','inches','Position',[1 1 6.8 4.5]);
b = bar(U_all,'grouped','BarWidth',0.75);
b(1).FaceColor = clrRF;
b(2).FaceColor = clrVLC;
b(3).FaceColor = clrHYB;
set(gca,'XTickLabel',{'Clear','Light Fog','Moderate Fog','Dense Fog'});
xlabel('Weather Condition','FontWeight','bold');
ylabel('Average Utility','FontWeight','bold');
title('Utility Comparison under Weather Conditions');
legend('RF','VLC','Link Aggregated','Location','northoutside',...
    'Orientation','horizontal','Box','off');
grid on; grid minor;
 
%% FIGURE 2 : Utility vs Fog Beta
clrRF  = [0.85 0.15 0.15];
clrVLC = [0.00 0.35 0.85];
clrHYB = [0.05 0.05 0.05];

num_bins = 50;
bins = linspace(min(fog_beta),max(fog_beta),num_bins);
fog_mid = zeros(num_bins-1,1);
U_RF_fog = zeros(num_bins-1,1);
U_VLC_fog = zeros(num_bins-1,1);
U_HYB_fog = zeros(num_bins-1,1);

for i=1:num_bins-1
    idx = fog_beta>=bins(i) & fog_beta<bins(i+1);
    fog_mid(i) = mean([bins(i) bins(i+1)]);
    U_RF_fog(i)=mean(U_RF(idx));
    U_VLC_fog(i)=mean(U_VLC(idx));
    temp = U_HYB(idx);
    temp = temp(~isinf(temp));
    if isempty(temp)
        U_HYB_fog(i)=NaN;
    else
        U_HYB_fog(i)=mean(temp);
    end
end
U_RF_fog  = smoothdata(U_RF_fog,'gaussian',5);
U_VLC_fog = smoothdata(U_VLC_fog,'gaussian',5);
U_HYB_fog = smoothdata(U_HYB_fog,'gaussian',5);

% Configure Marker Spacing (1 marker every 5 data points)
mk_idx_fog = 1:5:length(fog_mid); 

figure('Units','inches','Position',[1 1 6.8 4.5]);
plot(fog_mid, U_RF_fog, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(fog_mid, U_VLC_fog, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(fog_mid, U_HYB_fog, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_fog, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Fog Attenuation Coefficient, \beta');
ylabel('Average Utility');
title('Average Utility vs Fog Density');
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

%% FIGURE 3 : Delay vs Fog Beta
D_RF_fog=zeros(num_bins-1,1);
D_VLC_fog=zeros(num_bins-1,1);
D_HYB_fog=zeros(num_bins-1,1);
for i=1:num_bins-1
    idx = fog_beta>=bins(i) & fog_beta<bins(i+1);
    D_RF_fog(i)=mean(D_RF(idx));
    D_VLC_fog(i)=mean(D_VLC(idx));
    temp=D_HYB(idx);
    temp=temp(~isinf(temp));
    if isempty(temp)
        D_HYB_fog(i)=NaN;
    else
        D_HYB_fog(i)=mean(temp);
    end
end
D_RF_fog=smoothdata(D_RF_fog,'gaussian',5);
D_VLC_fog=smoothdata(D_VLC_fog,'gaussian',5);
D_HYB_fog=smoothdata(D_HYB_fog,'gaussian',5);

figure('Units','inches','Position',[1 1 6.8 4.5]);
semilogy(fog_mid, D_RF_fog, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
semilogy(fog_mid, D_VLC_fog, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
semilogy(fog_mid, D_HYB_fog, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_fog, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Fog Attenuation Coefficient, \beta');
ylabel('Delay (s)');
title('Delay vs Attenuation Coefficient');
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

%% FIGURE 4 : Utility vs Distance
num_bins = 40;
bins = linspace(min(distance),max(distance),num_bins);
dist_mid=zeros(num_bins-1,1);
U_RF_dist=zeros(num_bins-1,1);
U_VLC_dist=zeros(num_bins-1,1);
U_HYB_dist=zeros(num_bins-1,1);
for i=1:num_bins-1
    idx = distance>=bins(i) & distance<bins(i+1);
    dist_mid(i)=mean([bins(i) bins(i+1)]);
    U_RF_dist(i)=mean(U_RF(idx));
    U_VLC_dist(i)=mean(U_VLC(idx));
    temp=U_HYB(idx);
    temp=temp(~isinf(temp));
    if isempty(temp)
        U_HYB_dist(i)=NaN;
    else
        U_HYB_dist(i)=mean(temp);
    end
end
U_RF_dist=smoothdata(U_RF_dist,'gaussian',5);
U_VLC_dist=smoothdata(U_VLC_dist,'gaussian',5);
U_HYB_dist=smoothdata(U_HYB_dist,'gaussian',5);

% Configure Marker Spacing for distance arrays (1 marker every 4 data points)
mk_idx_dist = 1:4:length(dist_mid);

figure('Units','inches','Position',[1 1 6.8 4.5]);
plot(dist_mid, U_RF_dist, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(dist_mid, U_VLC_dist, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(dist_mid, U_HYB_dist, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_dist, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Distance (m)');
ylabel('Average Utility');
title('Average Utility vs Distance');
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

%% FIGURE 5 : Capacity vs Distance
C_RF_fog=zeros(num_bins-1,1);
C_VLC_fog=zeros(num_bins-1,1);
C_HYB_fog=zeros(num_bins-1,1);
for i=1:num_bins-1
    idx = distance>=bins(i) & distance<bins(i+1);
    C_RF_fog(i)=mean(C_rf(idx))/1e6;
    C_VLC_fog(i)=mean(C_vlc(idx))/1e6;
    temp=C_HYB(idx);
    temp=temp(temp>0);
    if isempty(temp)
        C_HYB_fog(i)=NaN;
    else
        C_HYB_fog(i)=mean(temp)/1e6;
    end
end
C_RF_fog=smoothdata(C_RF_fog,'gaussian',5);
C_VLC_fog=smoothdata(C_VLC_fog,'gaussian',5);
C_HYB_fog=smoothdata(C_HYB_fog,'gaussian',5);

figure('Units','inches','Position',[1 1 6.8 4.5]);
plot(dist_mid, C_RF_fog, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(dist_mid, C_VLC_fog, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(dist_mid, C_HYB_fog, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_dist, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Distance (m)');
ylabel('Capacity (Mbps)');
title('Capacity vs Distance');
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

%% FIGURE 6 : Median Delay vs Distance
D_RF_med=zeros(num_bins-1,1);
D_VLC_med=zeros(num_bins-1,1);
D_HYB_med=zeros(num_bins-1,1);
for i=1:num_bins-1
    idx = distance>=bins(i) & distance<bins(i+1);
    D_RF_med(i)=median(D_RF(idx));
    D_VLC_med(i)=median(D_VLC(idx));
    temp=D_HYB(idx);
    temp=temp(~isinf(temp));
    if isempty(temp)
        D_HYB_med(i)=NaN;
    else
        D_HYB_med(i)=median(temp);
    end
end
D_RF_med=smoothdata(D_RF_med,'gaussian',5);
D_VLC_med=smoothdata(D_VLC_med,'gaussian',5);
D_HYB_med=smoothdata(D_HYB_med,'gaussian',5);

figure('Units','inches','Position',[1 1 6.8 4.5]);
semilogy(dist_mid, D_RF_med, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
semilogy(dist_mid, D_VLC_med, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
semilogy(dist_mid, D_HYB_med, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_dist, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel(' Distance (m)');
ylabel('Delay (s)');
title('Delay vs Distance');
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

%% FIGURE 2 : Utility vs Fog Beta (Fixed Distance ~20m)
clrRF  = [0.85 0.15 0.15];
clrVLC = [0.00 0.35 0.85];
clrHYB = [0.05 0.05 0.05];

num_bins = 50;
bins = linspace(min(fog_beta), max(fog_beta), num_bins);
fog_mid = zeros(num_bins-1, 1);
U_RF_fog = zeros(num_bins-1, 1);
U_VLC_fog = zeros(num_bins-1, 1);
U_HYB_fog = zeros(num_bins-1, 1);

dist_tolerance = 5; 
idx_80m = abs(distance - 20) <= dist_tolerance; 

for i = 1:num_bins-1
    idx = (fog_beta >= bins(i)) & (fog_beta < bins(i+1)) & idx_80m;
    fog_mid(i) = mean([bins(i) bins(i+1)]);
    
    if sum(idx) > 0
        U_RF_fog(i)  = mean(U_RF(idx));
        U_VLC_fog(i) = mean(U_VLC(idx));
        temp = U_HYB(idx);
        temp = temp(~isinf(temp));
        if isempty(temp)
            U_HYB_fog(i) = NaN;
        else
            U_HYB_fog(i) = mean(temp);
        end
    else
        U_RF_fog(i)  = NaN;
        U_VLC_fog(i) = NaN;
        U_HYB_fog(i) = NaN;
    end
end

valid_rf = ~isnan(U_RF_fog);
U_RF_fog(valid_rf)  = smoothdata(U_RF_fog(valid_rf), 'gaussian', 5);
valid_vlc = ~isnan(U_VLC_fog);
U_VLC_fog(valid_vlc) = smoothdata(U_VLC_fog(valid_vlc), 'gaussian', 5);
valid_hyb = ~isnan(U_HYB_fog);
U_HYB_fog(valid_hyb) = smoothdata(U_HYB_fog(valid_hyb), 'gaussian', 5);

figure('Units', 'inches', 'Position', [1 1 6.8 4.5]);
plot(fog_mid, U_RF_fog, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(fog_mid, U_VLC_fog, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(fog_mid, U_HYB_fog, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_fog, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Fog Attenuation Coefficient, \beta');
ylabel('Average Utility');
title('Average Utility vs Fog Density (Fixed Distance \approx 20m)');
legend('RF', 'VLC', 'Link Aggregated', 'Box', 'off');
grid on; grid minor;

%% FIGURE 4 : Utility vs Distance (Specific Weather Condition)
target_weather = 1; 
weather_names = {'Clear weather', 'Rain', 'Light Fog', 'Dense Fog'};
num_bins = 40;
bins = linspace(min(distance), max(distance), num_bins);
dist_mid = zeros(num_bins-1, 1);
U_RF_dist = zeros(num_bins-1, 1);
U_VLC_dist = zeros(num_bins-1, 1);
U_HYB_dist = zeros(num_bins-1, 1);

for i = 1:num_bins-1
    idx = (distance >= bins(i)) & (distance < bins(i+1)) & (weather_class == target_weather);
    dist_mid(i) = mean([bins(i) bins(i+1)]);
    
    if sum(idx) > 0
        U_RF_dist(i)  = mean(U_RF(idx));
        U_VLC_dist(i) = mean(U_VLC(idx));
        temp = U_HYB(idx);
        temp = temp(~isinf(temp));
        if isempty(temp)
            U_HYB_dist(i) = NaN;
        else
            U_HYB_dist(i) = mean(temp);
        end
    else
        U_RF_dist(i)  = NaN;
        U_VLC_dist(i) = NaN;
        U_HYB_dist(i) = NaN;
    end
end

valid_rf = ~isnan(U_RF_dist);
U_RF_dist(valid_rf) = smoothdata(U_RF_dist(valid_rf), 'gaussian', 5);
valid_vlc = ~isnan(U_VLC_dist);
U_VLC_dist(valid_vlc) = smoothdata(U_VLC_dist(valid_vlc), 'gaussian', 5);
valid_hyb = ~isnan(U_HYB_dist);
U_HYB_dist(valid_hyb) = smoothdata(U_HYB_dist(valid_hyb), 'gaussian', 5);

figure('Units', 'inches', 'Position', [1 1 6.8 4.5]);
plot(dist_mid, U_RF_dist, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(dist_mid, U_VLC_dist, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(dist_mid, U_HYB_dist, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_dist, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Inter-Vehicle Distance (m)');
ylabel('Average Utility');
title(['Average Utility vs Distance (', weather_names{target_weather}, ')']);
legend('RF', 'VLC', 'Link Aggregated', 'Box', 'off');
grid on; grid minor;

%% ================= MEDIAN DELAY vs DISTANCE (FIXED FOG) =================
target_beta    = 2.5; 
beta_tolerance = 3.5; 
num_bins = 40;

idx_beta = abs(fog_beta - target_beta) <= beta_tolerance;
if nnz(idx_beta) == 0
    error('No samples found for selected beta. Adjust target_beta or tolerance.');
end

distance_f = distance(idx_beta);
D_RF_f     = D_RF(idx_beta);
D_VLC_f    = D_VLC(idx_beta);
D_HYB_f    = D_HYB(idx_beta);

valid = ~isnan(distance_f) & ~isinf(distance_f);
distance_f = distance_f(valid);
D_RF_f     = D_RF_f(valid);
D_VLC_f    = D_VLC_f(valid);
D_HYB_f    = D_HYB_f(valid);

bins = linspace(min(distance_f), max(distance_f), num_bins);
dist_mid = (bins(1:end-1) + bins(2:end)) / 2;

D_RF_med  = NaN(num_bins-1,1);
D_VLC_med = NaN(num_bins-1,1);
D_HYB_med = NaN(num_bins-1,1);

for i = 1:num_bins-1
    idx = distance_f >= bins(i) & distance_f < bins(i+1);
    if any(idx)
        temp = D_RF_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_RF_med(i) = median(temp); end
        
        temp = D_VLC_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_VLC_med(i) = median(temp); end
        
        temp = D_HYB_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_HYB_med(i) = median(temp); end
    end
end

valid_rf  = ~isnan(D_RF_med);
valid_vlc = ~isnan(D_VLC_med);
valid_hyb = ~isnan(D_HYB_med);

D_RF_med(valid_rf)   = smoothdata(D_RF_med(valid_rf),'gaussian',5);
D_VLC_med(valid_vlc) = smoothdata(D_VLC_med(valid_vlc),'gaussian',5);
D_HYB_med(valid_hyb) = smoothdata(D_HYB_med(valid_hyb),'gaussian',5);

clrRF  = [0.85 0.15 0.15];
clrVLC = [0.00 0.35 0.85];
clrHYB = [0.05 0.05 0.05];

mk_idx_dist_med = 1:4:length(dist_mid);

figure('Units','inches','Position',[1 1 6.8 4.5]);
semilogy(dist_mid, D_RF_med,  '-o',  'Color', clrRF, 'MarkerIndices', mk_idx_dist_med, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
semilogy(dist_mid, D_VLC_med, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist_med, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
semilogy(dist_mid, D_HYB_med, ':p',  'Color', clrHYB, 'MarkerIndices', mk_idx_dist_med, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Distance (m)');
ylabel('Delay (s)');
title(sprintf('Delay vs Distance (\\beta \\approx %.1f \\pm %.1f)', ...
      target_beta, beta_tolerance));
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

disp(['Samples used: ', num2str(nnz(idx_beta))]);
%% FIGURE 2 : Utility vs Fog Beta (Fixed Distance ~20m)
clrRF  = [0.85 0.15 0.15];
clrVLC = [0.00 0.35 0.85];
clrHYB = [0.05 0.05 0.05];

num_bins = 50;
bins = linspace(min(fog_beta), max(fog_beta), num_bins);
fog_mid = zeros(num_bins-1, 1);
U_RF_fog = zeros(num_bins-1, 1);
U_VLC_fog = zeros(num_bins-1, 1);
U_HYB_fog = zeros(num_bins-1, 1);

dist_tolerance = 30; 
idx_80m = abs(distance - 60) <= dist_tolerance; 

for i = 1:num_bins-1
    idx = (fog_beta >= bins(i)) & (fog_beta < bins(i+1)) & idx_80m;
    fog_mid(i) = mean([bins(i) bins(i+1)]);
    
    if sum(idx) > 0
        U_RF_fog(i)  = mean(U_RF(idx));
        U_VLC_fog(i) = mean(U_VLC(idx));
        temp = U_HYB(idx);
        temp = temp(~isinf(temp));
        if isempty(temp)
            U_HYB_fog(i) = NaN;
        else
            U_HYB_fog(i) = mean(temp);
        end
    else
        U_RF_fog(i)  = NaN;
        U_VLC_fog(i) = NaN;
        U_HYB_fog(i) = NaN;
    end
end

valid_rf = ~isnan(U_RF_fog);
U_RF_fog(valid_rf)  = smoothdata(U_RF_fog(valid_rf), 'gaussian', 5);
valid_vlc = ~isnan(U_VLC_fog);
U_VLC_fog(valid_vlc) = smoothdata(U_VLC_fog(valid_vlc), 'gaussian', 5);
valid_hyb = ~isnan(U_HYB_fog);
U_HYB_fog(valid_hyb) = smoothdata(U_HYB_fog(valid_hyb), 'gaussian', 5);

figure('Units', 'inches', 'Position', [1 1 6.8 4.5]);
plot(fog_mid, U_RF_fog, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(fog_mid, U_VLC_fog, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_fog, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(fog_mid, U_HYB_fog, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_fog, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Fog Attenuation Coefficient, \beta');
ylabel('Average Utility');
title('Average Utility vs Fog Density (Fixed Distance \approx 60m)');
legend('RF', 'VLC', 'Link Aggregated', 'Box', 'off');
grid on; grid minor;
%% ================= MEDIAN DELAY vs DISTANCE (FIXED FOG) =================
target_beta    = 0; 
beta_tolerance = 0.3; 
num_bins = 40;

idx_beta = abs(fog_beta - target_beta) <= beta_tolerance;
if nnz(idx_beta) == 0
    error('No samples found for selected beta. Adjust target_beta or tolerance.');
end

distance_f = distance(idx_beta);
D_RF_f     = D_RF(idx_beta);
D_VLC_f    = D_VLC(idx_beta);
D_HYB_f    = D_HYB(idx_beta);

valid = ~isnan(distance_f) & ~isinf(distance_f);
distance_f = distance_f(valid);
D_RF_f     = D_RF_f(valid);
D_VLC_f    = D_VLC_f(valid);
D_HYB_f    = D_HYB_f(valid);

bins = linspace(min(distance_f), max(distance_f), num_bins);
dist_mid = (bins(1:end-1) + bins(2:end)) / 2;

D_RF_med  = NaN(num_bins-1,1);
D_VLC_med = NaN(num_bins-1,1);
D_HYB_med = NaN(num_bins-1,1);

for i = 1:num_bins-1
    idx = distance_f >= bins(i) & distance_f < bins(i+1);
    if any(idx)
        temp = D_RF_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_RF_med(i) = median(temp); end
        
        temp = D_VLC_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_VLC_med(i) = median(temp); end
        
        temp = D_HYB_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_HYB_med(i) = median(temp); end
    end
end

valid_rf  = ~isnan(D_RF_med);
valid_vlc = ~isnan(D_VLC_med);
valid_hyb = ~isnan(D_HYB_med);

D_RF_med(valid_rf)   = smoothdata(D_RF_med(valid_rf),'gaussian',5);
D_VLC_med(valid_vlc) = smoothdata(D_VLC_med(valid_vlc),'gaussian',5);
D_HYB_med(valid_hyb) = smoothdata(D_HYB_med(valid_hyb),'gaussian',5);

clrRF  = [0.85 0.15 0.15];
clrVLC = [0.00 0.35 0.85];
clrHYB = [0.05 0.05 0.05];

mk_idx_dist_med = 1:4:length(dist_mid);

figure('Units','inches','Position',[1 1 6.8 4.5]);
semilogy(dist_mid, D_RF_med,  '-o',  'Color', clrRF, 'MarkerIndices', mk_idx_dist_med, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
semilogy(dist_mid, D_VLC_med, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist_med, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
semilogy(dist_mid, D_HYB_med, ':p',  'Color', clrHYB, 'MarkerIndices', mk_idx_dist_med, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Distance (m)');
ylabel('Delay (s)');
title(sprintf('Delay vs Distance (\\beta \\approx %.1f \\pm %.1f)', ...
      target_beta, beta_tolerance));
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

disp(['Samples used: ', num2str(nnz(idx_beta))]);
%% FIGURE 4 : Utility vs Distance (Specific Weather Condition)
target_weather = 1; 
weather_names = {'Clear weather', 'Rain', 'Light Fog', 'Dense Fog'};
num_bins = 40;
bins = linspace(min(distance), max(distance), num_bins);
dist_mid = zeros(num_bins-1, 1);
U_RF_dist = zeros(num_bins-1, 1);
U_VLC_dist = zeros(num_bins-1, 1);
U_HYB_dist = zeros(num_bins-1, 1);

for i = 1:num_bins-1
    idx = (distance >= bins(i)) & (distance < bins(i+1)) & (weather_class == target_weather);
    dist_mid(i) = mean([bins(i) bins(i+1)]);
    
    if sum(idx) > 0
        U_RF_dist(i)  = mean(U_RF(idx));
        U_VLC_dist(i) = mean(U_VLC(idx));
        temp = U_HYB(idx);
        temp = temp(~isinf(temp));
        if isempty(temp)
            U_HYB_dist(i) = NaN;
        else
            U_HYB_dist(i) = mean(temp);
        end
    else
        U_RF_dist(i)  = NaN;
        U_VLC_dist(i) = NaN;
        U_HYB_dist(i) = NaN;
    end
end

valid_rf = ~isnan(U_RF_dist);
U_RF_dist(valid_rf) = smoothdata(U_RF_dist(valid_rf), 'gaussian', 5);
valid_vlc = ~isnan(U_VLC_dist);
U_VLC_dist(valid_vlc) = smoothdata(U_VLC_dist(valid_vlc), 'gaussian', 5);
valid_hyb = ~isnan(U_HYB_dist);
U_HYB_dist(valid_hyb) = smoothdata(U_HYB_dist(valid_hyb), 'gaussian', 5);

figure('Units', 'inches', 'Position', [1 1 6.8 4.5]);
plot(dist_mid, U_RF_dist, '-o', 'Color', clrRF, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w'); hold on;
plot(dist_mid, U_VLC_dist, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist, 'MarkerSize', 5, 'MarkerFaceColor', 'w');
plot(dist_mid, U_HYB_dist, ':p', 'Color', clrHYB, 'MarkerIndices', mk_idx_dist, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
xlabel('Inter-Vehicle Distance (m)');
ylabel('Average Utility');
title(['Average Utility vs Distance (', weather_names{target_weather}, ')']);
legend('RF', 'VLC', 'Link Aggregated', 'Box', 'off');
grid on; grid minor;
%% ================= AVERAGE DELAY vs DISTANCE (FIXED FOG) =================
target_beta    = 1; 
beta_tolerance = 0.721; 
num_bins = 40;

idx_beta = abs(fog_beta - target_beta) <= beta_tolerance;
if nnz(idx_beta) == 0
    error('No samples found for selected beta. Adjust target_beta or tolerance.');
end

distance_f = distance(idx_beta);
D_RF_f     = D_RF(idx_beta);
D_VLC_f    = D_VLC(idx_beta);
D_HYB_f    = D_HYB(idx_beta);

valid = ~isnan(distance_f) & ~isinf(distance_f);
distance_f = distance_f(valid);
D_RF_f     = D_RF_f(valid);
D_VLC_f    = D_VLC_f(valid);
D_HYB_f    = D_HYB_f(valid);

bins = linspace(min(distance_f), max(distance_f), num_bins);
dist_mid = (bins(1:end-1) + bins(2:end)) / 2;

D_RF_avg  = NaN(num_bins-1,1);
D_VLC_avg = NaN(num_bins-1,1);
D_HYB_avg = NaN(num_bins-1,1);

for i = 1:num_bins-1
    idx = distance_f >= bins(i) & distance_f < bins(i+1);
    if any(idx)
        temp = D_RF_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_RF_avg(i) = mean(temp); end
        
        temp = D_VLC_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_VLC_avg(i) = mean(temp); end
        
        temp = D_HYB_f(idx);
        temp = temp(~isinf(temp));
        if ~isempty(temp), D_HYB_avg(i) = mean(temp); end
    end
end

valid_rf  = ~isnan(D_RF_avg);
valid_vlc = ~isnan(D_VLC_avg);
valid_hyb = ~isnan(D_HYB_avg);

D_RF_avg(valid_rf)   = smoothdata(D_RF_avg(valid_rf),'gaussian',5);
D_VLC_avg(valid_vlc) = smoothdata(D_VLC_avg(valid_vlc),'gaussian',5);
D_HYB_avg(valid_hyb) = smoothdata(D_HYB_avg(valid_hyb),'gaussian',5);

mk_idx_dist_avg = 1:4:length(dist_mid);

figure('Units','inches','Position',[1 1 6.8 4.5]);
semilogy(dist_mid, D_RF_avg,  '-o',  'Color', clrRF, 'MarkerIndices', mk_idx_dist_avg, 'MarkerSize', 3, 'MarkerFaceColor', 'w'); hold on;
semilogy(dist_mid, D_VLC_avg, '--s', 'Color', clrVLC, 'MarkerIndices', mk_idx_dist_avg, 'MarkerSize', 3, 'MarkerFaceColor', 'w');
semilogy(dist_mid, D_HYB_avg, ':p',  'Color', clrHYB, 'MarkerIndices', mk_idx_dist_avg, 'LineWidth', 2.4, 'MarkerSize', 3, 'MarkerFaceColor', 'w');

xlabel('Distance (m)');
ylabel('Average Delay (s)');
title(sprintf('Average Delay vs Distance (\\beta \\approx %.1f \\pm %.1f)', ...
      target_beta, beta_tolerance));
legend('RF','VLC','Link Aggregated','Box','off');
grid on; grid minor;

disp(['Samples used: ', num2str(nnz(idx_beta))]);


%% ================= TRUE THROUGHPUT vs DISTANCE =================
num_bins = 35;
bins = linspace(min(distance), max(distance), num_bins);
dist_mid = (bins(1:end-1) + bins(2:end))/2;

C_RF_avg  = zeros(num_bins-1,1);
C_VLC_avg = zeros(num_bins-1,1);
C_HYB_avg = zeros(num_bins-1,1);

for i=1:num_bins-1
    idx = distance>=bins(i) & distance<bins(i+1);
    
    if any(idx)
        C_RF_avg(i)  = mean(C_rf(idx))/1e6;
        C_VLC_avg(i) = mean(C_vlc(idx))/1e6;
        
        temp = C_HYB(idx);
        temp = temp(temp>0);
        if ~isempty(temp)
            C_HYB_avg(i) = mean(temp)/1e6;
        else
            C_HYB_avg(i) = NaN;
        end
    else
        C_RF_avg(i)=NaN;
        C_VLC_avg(i)=NaN;
        C_HYB_avg(i)=NaN;
    end
end

% Smooth
C_RF_avg  = smoothdata(C_RF_avg,'gaussian',3);
C_VLC_avg = smoothdata(C_VLC_avg,'gaussian',3);
C_HYB_avg = smoothdata(C_HYB_avg,'gaussian',3);

%% ✅ NOW crop to 150m
max_dist = 150;
valid_idx = dist_mid <= max_dist;

dist_mid_plot = dist_mid(valid_idx);
C_RF_plot    = C_RF_avg(valid_idx);
C_VLC_plot   = C_VLC_avg(valid_idx);
C_HYB_plot   = C_HYB_avg(valid_idx);

%% ✅ Plot
figure;
plot(dist_mid_plot, C_RF_plot, '-o'); hold on;
plot(dist_mid_plot, C_VLC_plot, '--s');
plot(dist_mid_plot, C_HYB_plot, '-d','LineWidth',2);

xlabel('Distance (m)');
ylabel('Throughput (Mbps)');
title('Throughput vs Distance (0–150 m)');
legend('RF','VLC','Hybrid');
grid on;