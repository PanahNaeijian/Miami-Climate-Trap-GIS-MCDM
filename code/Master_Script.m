%% CLIMATE-RESILIENT WATER REUSE MODEL (FINAL MANUSCRIPT VERSION)

clc; clear; close all;

%_______________________________________________________________
% SECTION 1: SETUP & DATA LOADING
%_______________________________________________________________
basePath = 'E:\Academic\Projects\Panah\1\Dataset\';
disp('------------------------------------------------');
disp('STEP 1: Loading Pre-processed Data...');

% 1. Load Elevation (Master)
demPath = fullfile(basePath, '1-Elevation (DEM)', 'USGS_13_n26w081_20231221.tif');
[dem_grid, R] = readgeoraster(demPath);
dem_grid = double(dem_grid);
dem_grid(dem_grid < -100) = NaN; % Fix No-Data

% 2. Load Aligned Land Use
landPath = fullfile(basePath, '2-Land Use', 'LandUse_Miami_Aligned.tif');
if ~isfile(landPath)
    error('File not found! Run the Python prep script first.');
end
[land_aligned, ~] = readgeoraster(landPath);
land_aligned = double(land_aligned);

% 3. Load ALL THREE Aligned Sea Level Rise Scenarios
% Baseline (Intermediate-High)
slrPath = fullfile(basePath, '3-Sea Level Rise', 'SLR_Miami_Aligned.tif');
[slr_aligned, ~] = readgeoraster(slrPath);
slr_aligned = double(slr_aligned);
slr_aligned(isnan(slr_aligned)) = 0;

% Low Scenario (1.0 ft)
slrLowPath = fullfile(basePath, '3-Sea Level Rise', 'SLR_Miami_Aligned_Low.tif');
[slr_low, ~] = readgeoraster(slrLowPath);
slr_low = double(slr_low);
slr_low(isnan(slr_low)) = 0;

% Extreme Scenario (3.0 ft)
slrExtPath = fullfile(basePath, '3-Sea Level Rise', 'SLR_Miami_Aligned_Extreme.tif');
[slr_ext, ~] = readgeoraster(slrExtPath);
slr_ext = double(slr_ext);
slr_ext(isnan(slr_ext)) = 0;

% Get dimensions and Pixel Size
[rows, cols] = size(dem_grid);
pixel_area_m2 = 10 * 10; % Approx 10x10m resolution
pixel_area_km2 = pixel_area_m2 / 10^6;

disp(['Data Loaded. Grid Size: ', num2str(rows), ' x ', num2str(cols)]);

%_______________________________________________________________
% SECTION 2: MODELING & SCORING (Expanded Criteria)
%_______________________________________________________________
disp('STEP 2: Running Expanded MCDM Model...');

% --- CRITERIA 1: SLOPE ---
[~, slope_degrees] = gradient(dem_grid);
slope_norm = 1 - (slope_degrees ./ 10); 
slope_norm(slope_norm < 0) = 0;         
slope_norm(isnan(slope_norm)) = 0;      

% --- CRITERIA 2: LAND USE ---
suitability_land = zeros(rows, cols);
suitability_land(land_aligned == 21) = 1.0; % Open Space
suitability_land(land_aligned == 22) = 0.8; % Low Intensity
suitability_land(land_aligned == 23) = 0.5; % Med Intensity
suitability_land(land_aligned == 24) = 0.2; % High Intensity
suitability_land(land_aligned == 11) = 0.0; % Water

% --- CRITERIA 3: DISTANCE TO DEMAND ---
demand_mask = (land_aligned == 23) | (land_aligned == 24);
dist_to_demand = bwdist(demand_mask) * 10; % Euclidean distance in meters
max_viable_distance = 5000; % 5km maximum pumping distance
suitability_dist = 1 - (dist_to_demand / max_viable_distance);
suitability_dist(suitability_dist < 0) = 0; 

% --- CLIMATE VETO (BASELINE) ---
suitability_climate = ones(rows, cols);
suitability_climate(slr_aligned > 0) = 0;

% --- FINAL CALCULATION ---
W_LandUse  = 0.50;
W_Distance = 0.30;
W_Slope    = 0.20;

Base_Score = (slope_norm * W_Slope) + (suitability_land * W_LandUse) + (suitability_dist * W_Distance);
Final_Map = Base_Score .* suitability_climate;

%_______________________________________________________________
% SECTION 3: STATISTICAL ANALYSIS (FOR TABLES)
%_______________________________________________________________
disp('------------------------------------------------');
disp('STEP 3: Generating Statistics for Tables...');

valid_mask = (dem_grid > 0) | (land_aligned > 0);
total_area_km2 = sum(valid_mask(:)) * pixel_area_km2;
disp(['Total Study Area: ', num2str(total_area_km2), ' km^2']);

% Table 3: Suitability Classes
high_pixels = sum(Final_Map(:) >= 0.7);
mod_pixels  = sum(Final_Map(:) >= 0.4 & Final_Map(:) < 0.7);
low_pixels  = sum(Final_Map(:) < 0.4 & valid_mask(:)); 

disp('--- TABLE 3 DATA ---');
disp(['High Suitability: ', num2str(high_pixels * pixel_area_km2), ' km^2']);
disp(['Mod Suitability:  ', num2str(mod_pixels * pixel_area_km2), ' km^2']);
disp(['Low Suitability:  ', num2str(low_pixels * pixel_area_km2), ' km^2']);

% Table 4: Climate Trap Analysis - STRESS TEST
disp('--- TABLE 4 DATA: CLIMATE TRAP STRESS TEST ---');
climate_scenarios = {slr_low, slr_aligned, slr_ext};
scenario_names = {'Optimistic (1.0 ft)', 'Intermediate-High (Baseline)', 'Extreme (3.0 ft)'};

for idx = 1:length(climate_scenarios)
    current_veto = ones(rows, cols);
    current_veto(climate_scenarios{idx} > 0) = 0; 
    temp_final_map = Base_Score .* current_veto;
    lost_mask = (Base_Score >= 0.7) & (temp_final_map == 0);
    disp([scenario_names{idx}, ' Trap Area: ', num2str(sum(lost_mask(:)) * pixel_area_km2), ' km^2']);
end

%_______________________________________________________________
% SECTION 4: FIGURE GENERATION (CORE MAPS)
%_______________________________________________________________
disp('------------------------------------------------');
disp('STEP 4: Generating Core Figures...');

% --- FIGURE 1: INPUT DATA (CINEMATIC) ---
f1 = figure('Name', 'Figure 1: Inputs', 'Color', 'w', 'Position', [100 100 1200 450]);
t = tiledlayout(1, 3, 'TileSpacing', 'tight', 'Padding', 'compact');

nexttile;
imagesc(dem_grid); colormap(gca, parula); axis image; axis off;
title('A. Topography (DEM)', 'FontSize', 12, 'FontWeight', 'bold');
box on; set(gca, 'LineWidth', 1, 'XColor', 'k', 'YColor', 'k');

nexttile;
imagesc(land_aligned);
map_custom = [0.2 0.4 0.8; 0.4 0.7 0.4; 0.9 0.8 0.3; 0.8 0.2 0.2]; 
colormap(gca, jet); axis image; axis off;
title('B. Urban Land Use', 'FontSize', 12, 'FontWeight', 'bold');
box on; set(gca, 'LineWidth', 1, 'XColor', 'k', 'YColor', 'k');

nexttile;
imagesc(slr_aligned); colormap(gca, cool); axis image; axis off;
title('C. 2050 Inundation', 'FontSize', 12, 'FontWeight', 'bold');
box on; set(gca, 'LineWidth', 1, 'XColor', 'k', 'YColor', 'k');
exportgraphics(gcf, 'Fig1_Cinematic.png', 'Resolution', 300);

% --- FIGURE 2: FINAL SUITABILITY MAP ---
figure('Name', 'Figure 2: Final Map', 'Color', 'w');
imagesc(Final_Map); colormap(jet); colorbar; caxis([0 1]);
title('Climate-Resilient Water Reuse Zones (Miami 2050)');
subtitle('Red = Best | Blue = Unsuitable/Flooded');
exportgraphics(gcf, 'Fig2_SuitabilityMap.png', 'Resolution', 300);

% --- FIGURE 3: THE CLIMATE TRAP ---
lost_land_mask = (Base_Score >= 0.7) & (Final_Map == 0);
figure('Name', 'Figure 3: Climate Trap', 'Color', 'w');
imshow(dem_grid, [], 'Colormap', gray); hold on;
red_overlay = cat(3, ones(size(dem_grid)), zeros(size(dem_grid)), zeros(size(dem_grid)));
h = imshow(red_overlay); set(h, 'AlphaData', lost_land_mask); 
title('Figure 3: The "Climate Trap"');
subtitle('Red Areas = High Suitability Land Lost to 2050 Flooding');
exportgraphics(gcf, 'Fig3_ClimateTrap.png', 'Resolution', 300);

% --- FIGURE 4: ADVANCED SENSITIVITY ---
slope_weights = 0.1:0.1:0.9;
mean_results = zeros(size(slope_weights));
upper_bound = zeros(size(slope_weights));
lower_bound = zeros(size(slope_weights));

for i = 1:length(slope_weights)
    w_s = slope_weights(i);
    w_l = 1.0 - w_s; 
    Main_Map = ((slope_norm * w_s) + (suitability_land * w_l)) .* suitability_climate;
    mean_results(i) = sum(Main_Map(:) >= 0.7) * pixel_area_km2;
    Map_High = ((slope_norm * (w_s+0.05)) + (suitability_land * (w_l-0.05))) .* suitability_climate;
    Map_Low  = ((slope_norm * (w_s-0.05)) + (suitability_land * (w_l+0.05))) .* suitability_climate;
    upper_bound(i) = sum(Map_High(:) >= 0.7) * pixel_area_km2;
    lower_bound(i) = sum(Map_Low(:) >= 0.7) * pixel_area_km2;
end

figure('Name', 'Figure 4: Sensitivity', 'Color', 'w'); hold on;
x_conf = [slope_weights, fliplr(slope_weights)];
y_conf = [lower_bound, fliplr(upper_bound)];
fill(x_conf, y_conf, [0.85 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5); 
plot(slope_weights, mean_results, '-bo', 'LineWidth', 2.5, 'MarkerFaceColor', 'b', 'MarkerSize', 6);
xline(0.6, '--k', 'Critical Threshold', 'LabelVerticalAlignment', 'bottom', 'FontSize', 10);
grid on;
xlabel('Weight Assigned to Slope (W_s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Total Suitable Area (km^2)', 'FontSize', 12, 'FontWeight', 'bold');
title('Sensitivity Analysis', 'FontSize', 14);
legend({'Stability Range (\pm5%)', 'Mean Suitability'}, 'Location', 'NorthWest');
exportgraphics(gcf, 'Fig4_Sensitivity.png', 'Resolution', 300);

% --- FIGURE 5: MICRO-ANALYSIS ZOOM ---
win = 200; max_variance = 0; best_row = 5000; best_col = 5000;
for r = 1:500:(rows - win)
    for c = 1:500:(cols - win)
        chunk = Final_Map(r:r+win, c:c+win);
        current_var = std(chunk(:));
        if current_var > max_variance
            max_variance = current_var; best_row = r; best_col = c;
        end
    end
end
Zoom_Map = Final_Map(best_row : best_row+win, best_col : best_col+win);

figure('Name', 'Figure 5: Final', 'Color', 'w');
imagesc(Zoom_Map); colormap(jet); axis off; axis equal;
title({'Micro-Scale Suitability Analysis', 'Downtown/Coastal Interface Zone'}, 'FontSize', 14, 'FontWeight', 'bold');
c = colorbar; c.Label.String = 'Suitability Index (0-1)'; c.Label.FontSize = 10; c.Label.FontWeight = 'bold';
hold on; plot([20 70], [180 180], '-w', 'LineWidth', 3);
text(45, 170, '1 km', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 10);
text(180, 20, 'N', 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');
text(180, 35, '^', 'Color', 'w', 'FontSize', 18, 'FontWeight', 'bold', 'Interpreter', 'none');
exportgraphics(gcf, 'Fig5_MicroAnalysis.png', 'Resolution', 600);

%_______________________________________________________________
% SECTION 5: ADVANCED ENRICHMENT
%_______________________________________________________________
disp('STEP 5: Running Advanced Enrichment...');

% 1. CLUSTER ANALYSIS (Figure 6)
High_Suit_Mask = Final_Map >= 0.7;
CC = bwconncomp(High_Suit_Mask);
stats = regionprops(CC, 'Area', 'PixelIdxList');
min_pixels = 100; Large_Site_Map = zeros(rows, cols); count_sites = 0;

for i = 1:CC.NumObjects
    if stats(i).Area >= min_pixels
        Large_Site_Map(stats(i).PixelIdxList) = 1; count_sites = count_sites + 1;
    end
end

figure('Name', 'Figure 6: Viable Sites', 'Color', 'w');
imshow(dem_grid, [], 'Colormap', gray); hold on;
green_overlay = cat(3, zeros(size(dem_grid)), ones(size(dem_grid)), zeros(size(dem_grid)));
h = imshow(green_overlay); set(h, 'AlphaData', Large_Site_Map); 
title('Figure 6: Viable Construction Sites (>1 Hectare)');
exportgraphics(gcf, 'Fig6_ViableSites.png', 'Resolution', 300);

% 2. LAND USE COMPOSITION (Figure 7)
mask_developed = ismember(land_aligned, [21, 22, 23, 24]);
all_dev_types = land_aligned(mask_developed);
gen_counts = [sum(all_dev_types == 21), sum(all_dev_types == 22), sum(all_dev_types == 23), sum(all_dev_types == 24)];
gen_pct = (gen_counts / sum(gen_counts)) * 100;

optimal_land_types = land_aligned(High_Suit_Mask);
opt_counts = [sum(optimal_land_types == 21), sum(optimal_land_types == 22), sum(optimal_land_types == 23), sum(optimal_land_types == 24)];
opt_pct = (opt_counts / sum(opt_counts)) * 100;

figure('Name', 'Figure 7: Advanced Stats', 'Color', 'w', 'Position', [100 100 900 600]);
b = bar([gen_pct; opt_pct]', 'grouped');
b(1).FaceColor = [0.6 0.6 0.6]; b(2).FaceColor = [0.1 0.5 0.2];
b(1).EdgeColor = 'none'; b(2).EdgeColor = 'none';
grid on; set(gca, 'GridAlpha', 0.3);
ylabel('Land Composition (%)', 'FontSize', 12, 'FontWeight', 'bold');
xticklabels({'Open Space', 'Low Intensity', 'Med Intensity', 'High Intensity'});
legend({'Regional Availability', 'Model Selection'}, 'Location', 'NorthWest', 'FontSize', 11);
title('Selectivity Analysis of Spatial Optimization', 'FontSize', 14);

for k = 1:2
    xtips = b(k).XEndPoints; ytips = b(k).YEndPoints;
    labels = string(round(b(k).YData, 1)) + "%";
    text(xtips, ytips, labels, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
end
gain = opt_pct(2) - gen_pct(2); rejection = gen_pct(4) - opt_pct(4);
msg = {['\bf Model Selectivity Metrics:'], ['\rm \color[rgb]{0 0.5 0}\uparrow Low Density Preference: +', num2str(round(gain,1)), '%'], ['\color[rgb]{0.8 0 0}\downarrow High Density Rejection: -', num2str(round(rejection,1)), '%'], ['\color{black} \it Conclusion: Model successfully prioritizes'], ['\it low-conflict suburban zones.']};
annotation('textbox', [0.6, 0.6, 0.25, 0.2], 'String', msg, 'FitBoxToText', 'on', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1);
exportgraphics(gcf, 'Fig7_AdvancedStats.png', 'Resolution', 300);

% 3. BUFFER ANALYSIS (Figure 8)
flood_zone_mask = slr_aligned > 0;
dist_in_pixels = bwdist(flood_zone_mask);
dist_in_meters = dist_in_pixels * 10;
Viable_Site_Distances = dist_in_meters .* Large_Site_Map;

Safety_Map = zeros(rows, cols);
Safety_Map(Large_Site_Map == 1) = 1; 
Safety_Map(Viable_Site_Distances > 500) = 2; 
Safety_Map(Viable_Site_Distances > 1500) = 3; 
Safety_Map(Large_Site_Map == 0) = 0; 

figure('Name', 'Figure 8: Coastal Buffer', 'Color', 'w');
imagesc(Safety_Map);
risk_cmap = [0.1 0.1 0.1; 1 0 0; 1 1 0; 0 1 0]; colormap(risk_cmap);
colorbar('Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', '<500m (Surge Risk)', '500-1500m', '>1.5km (Safe)'});
title('Figure 8: Coastal Safety Buffer Analysis'); axis off; axis equal;
exportgraphics(gcf, 'Fig8_BufferAnalysis.png', 'Resolution', 300);

% 4. ECONOMIC ANALYSIS (Figure 9)
Site_Cost_Map = dist_to_demand .* Large_Site_Map;
Economic_Map = zeros(rows, cols);
Economic_Map(Large_Site_Map == 1) = 1; 
Economic_Map(Site_Cost_Map > 0 & Site_Cost_Map < 2000) = 2; 
Economic_Map(Site_Cost_Map > 0 & Site_Cost_Map < 500)  = 3; 
Economic_Map(Large_Site_Map == 0) = 0; 

figure('Name', 'Figure 9: Econ Efficiency', 'Color', 'w');
imagesc(Economic_Map);
econ_cmap = [0.1 0.1 0.1; 0.8 0.2 0.2; 0.9 0.8 0.1; 0 0.8 0.2]; colormap(econ_cmap);
colorbar('Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', 'Low Eff.', 'Mod Eff.', 'High Eff.'});
title('Figure 9: Economic Efficiency Analysis'); axis off; axis equal;
exportgraphics(gcf, 'Fig9_EconomicAnalysis.png', 'Resolution', 300);

disp('------------------------------------------------');
disp('ALL STATS AND 9 FIGURES GENERATED SUCCESSFULLY.');
disp('Project Complete.');

disp('--- MISSING ENRICHMENT STATISTICS ---');

% 1. Calculate Section 3.4 Stats (Morphology)
total_viable_area = sum(Large_Site_Map(:)) * pixel_area_km2;
raw_high_area = sum(Final_Map(:) >= 0.7) * pixel_area_km2;
fragmentation_loss = raw_high_area - total_viable_area;

disp(['Sec 3.4 - Viable Construction Sites (>1ha): ', num2str(count_sites)]);
disp(['Sec 3.4 - Total Viable Area: ', num2str(total_viable_area), ' km^2']);
disp(['Sec 3.4 - Land Lost to Fragmentation: ', num2str(fragmentation_loss), ' km^2']);

% 2. Calculate Section 3.6 / 5.3 Stats (Buffers & Proximity)
% Calculate distance mathematically to ensure accuracy
risk_buffer_area = sum(Large_Site_Map(:) == 1 & dist_in_meters(:) <= 500) * pixel_area_km2;
risk_buffer_pct = (risk_buffer_area / total_viable_area) * 100;

high_eff_area = sum(Large_Site_Map(:) == 1 & dist_to_demand(:) <= 500) * pixel_area_km2;
low_eff_area = sum(Large_Site_Map(:) == 1 & dist_to_demand(:) > 2000) * pixel_area_km2;

disp(['Sec 3.6 - Coastal Risk Buffer (<500m): ', num2str(risk_buffer_area), ' km^2 (', num2str(risk_buffer_pct), '%)']);
disp(['Sec 3.6/5.3 - High Econ Efficiency Corridor (<500m to demand): ', num2str(high_eff_area), ' km^2']);
disp(['Sec 3.6 - Low Econ Efficiency (>2km to demand): ', num2str(low_eff_area), ' km^2']);
disp('---------------------------------------------');

disp('--- NEW TABLE 5 DATA ---');
High_Suit_Mask = Final_Map >= 0.7;
optimal_land_types = land_aligned(High_Suit_Mask);
counts = [sum(optimal_land_types == 21), sum(optimal_land_types == 22), sum(optimal_land_types == 23), sum(optimal_land_types == 24)];
percentages = (counts / sum(counts)) * 100;
disp(['Open Space:     ', num2str(percentages(1)), '%']);
disp(['Low Intensity:  ', num2str(percentages(2)), '%']);
disp(['Med Intensity:  ', num2str(percentages(3)), '%']);
disp(['High Intensity: ', num2str(percentages(4)), '%']);

%_______________________________________________________________
% FIGURE 7: SOPHISTICATED LAND USE SELECTIVITY ANALYSIS
%_______________________________________________________________
disp('Generating Figure 7...');

% 1. Regional Land Cover Composition (Developed Classes)
mask_developed = ismember(land_aligned, [21, 22, 23, 24]);
all_dev_types = land_aligned(mask_developed);
gen_counts = [sum(all_dev_types == 21), sum(all_dev_types == 22), ...
              sum(all_dev_types == 23), sum(all_dev_types == 24)];
gen_pct = (gen_counts / sum(gen_counts)) * 100;

% 2. Model Selection Composition (Optimal Zones: SI >= 0.7)
High_Suit_Mask = (Final_Map >= 0.7);
optimal_land_types = land_aligned(High_Suit_Mask);
opt_counts = [sum(optimal_land_types == 21), sum(optimal_land_types == 22), ...
              sum(optimal_land_types == 23), sum(optimal_land_types == 24)];
opt_pct = (opt_counts / sum(opt_counts)) * 100;

% 3. Create Figure
figure('Name', 'Figure 7: Advanced Stats', 'Color', 'w', 'Position', [100 100 900 600]);

% Data Matrix: Row 1 = Regional Availability, Row 2 = Model Selection
data_matrix = [gen_pct; opt_pct]';

b = bar(data_matrix, 'grouped');
b(1).FaceColor = [0.6 0.6 0.6]; % Muted Gray (Regional Baseline)
b(2).FaceColor = [0.1 0.5 0.2]; % Forest Green (Model Portfolio)
b(1).EdgeColor = 'none';
b(2).EdgeColor = 'none';

% Axes & Labels
grid on; set(gca, 'GridAlpha', 0.3);
ylabel('Land Composition (%)', 'FontSize', 12, 'FontWeight', 'bold');
xticklabels({'Open Space (21)', 'Low Intensity (22)', 'Med Intensity (23)', 'High Intensity (24)'});
legend({'Regional Availability', 'Model Selection'}, 'Location', 'NorthWest', 'FontSize', 11);
title('Selectivity Analysis of Spatial Optimization', 'FontSize', 14);
subtitle('Comparison of Regional Land Availability vs. Optimal Site Composition');

% 4. Add Text Labels Above Each Bar
for k = 1:2
    xtips = b(k).XEndPoints;
    ytips = b(k).YEndPoints;
    labels = string(round(b(k).YData, 1)) + "%";
    text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
end

% 5. Dynamic Annotation Box
msg = {['\bf Model Selectivity Insights:'], ...
       ['\rm \color[rgb]{0 0.5 0}\uparrow Urban Corridor Integration: Med Intensity Selected (44.7%)'], ...
       ['\color[rgb]{0.8 0 0}\downarrow Complete Urban Core Exclusion: High Intensity (0.0%)'], ...
       ['\color{black}\it Proximity to demand drives selection of transitional urban edges'], ...
       ['\it while strictly rejecting hyper-dense cores.']};

annotation('textbox', [0.52, 0.62, 0.35, 0.22], 'String', msg, ...
    'FitBoxToText', 'on', 'BackgroundColor', 'w', 'EdgeColor', 'k', 'LineWidth', 1);

% Export
exportgraphics(gcf, 'Fig7_AdvancedStats.png', 'Resolution', 300);
disp('Figure 7 Generated Successfully.');


% ==========================================================
% GENERATING PUBLICATION-READY COMPOSITE FIGURES
% ==========================================================
disp('Generating New Composite Figures...');

% Common formatting variables
fontN = 'Arial';
fontS = 8;
scale_len_5km = 500; % 500 pixels * 10m = 5km

% ----------------------------------------------------------
% NEW FIGURE 2: SUITABILITY & CLIMATE TRAP (Combines old Fig 3 & 4)
% ----------------------------------------------------------
f2 = figure('Name', 'New Fig 2: Suitability & Trap', 'Color', 'w', 'Position', [100 100 1200 500]);

% Panel A: Suitability
ax1 = subplot(1, 2, 1);
imagesc(Final_Map); colormap(ax1, jet); caxis(ax1, [0 1]);
axis(ax1, 'image'); axis(ax1, 'off');
title('(a) Final Suitability Surface', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
c1 = colorbar(ax1); c1.Label.String = 'Suitability Index'; c1.FontName = fontN; c1.FontSize = fontS;
% 5km Scale Bar
hold(ax1, 'on'); plot(ax1, [500 500+scale_len_5km], [rows-500 rows-500], 'k-', 'LineWidth', 3);
text(ax1, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');

% Panel B: Climate Trap
ax2 = subplot(1, 2, 2);
imshow(dem_grid, [], 'Colormap', gray, 'Parent', ax2); hold(ax2, 'on');
lost_land_mask = (Base_Score >= 0.7) & (Final_Map == 0);
red_overlay = cat(3, ones(size(dem_grid)), zeros(size(dem_grid)), zeros(size(dem_grid)));
h = imshow(red_overlay, 'Parent', ax2); set(h, 'AlphaData', lost_land_mask);
axis(ax2, 'image'); axis(ax2, 'off');
title('(b) Climate Trap (Lost Assets)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
% 5km Scale Bar (White for contrast)
plot(ax2, [500 500+scale_len_5km], [rows-500 rows-500], 'w-', 'LineWidth', 3);
text(ax2, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');

exportgraphics(f2, 'New_Figure_2.png', 'Resolution', 600);

% ----------------------------------------------------------
% NEW FIGURE 3: MORPHOLOGY & SELECTIVITY (Combines old Fig 6a, 6b, & 7)
% ----------------------------------------------------------
f3 = figure('Name', 'New Fig 3: Morphology', 'Color', 'w', 'Position', [100 100 1500 450]);

% Panel A: Raw Pixels (Zoom Map)
ax3 = subplot(1, 3, 1);
imagesc(Zoom_Map); colormap(ax3, jet); caxis(ax3, [0 1]);
axis(ax3, 'image'); axis(ax3, 'off');
title('(a) Raw Pixel Fragmentation', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
% 1km Scale bar for zoom map (100 pixels = 1km)
hold(ax3, 'on'); plot(ax3, [20 120], [180 180], 'w-', 'LineWidth', 3);
text(ax3, 70, 170, '1 km', 'FontName', fontN, 'FontSize', fontS, 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Panel B: Viable Sites
ax4 = subplot(1, 3, 2);
imshow(dem_grid, [], 'Colormap', gray, 'Parent', ax4); hold(ax4, 'on');
green_overlay = cat(3, zeros(size(dem_grid)), ones(size(dem_grid)), zeros(size(dem_grid)));
h2 = imshow(green_overlay, 'Parent', ax4); set(h2, 'AlphaData', Large_Site_Map);
axis(ax4, 'image'); axis(ax4, 'off');
title('(b) Filtered Contiguous Sites (>1ha)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
% 5km Scale Bar
plot(ax4, [500 500+scale_len_5km], [rows-500 rows-500], 'w-', 'LineWidth', 3);
text(ax4, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Panel C: Land Use Bar Chart
ax5 = subplot(1, 3, 3);
data_matrix = [gen_pct; opt_pct]';
b = bar(ax5, data_matrix, 'grouped');
b(1).FaceColor = [0.6 0.6 0.6]; b(1).EdgeColor = 'none';
b(2).FaceColor = [0.1 0.5 0.2]; b(2).EdgeColor = 'none';
grid(ax5, 'on'); set(ax5, 'FontName', fontN, 'FontSize', fontS);
ylabel(ax5, 'Land Composition (%)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
xticklabels(ax5, {'Open Space', 'Low Intensity', 'Med Intensity', 'High Int.'});
legend(ax5, {'Regional Availability', 'Model Selection'}, 'Location', 'NorthWest', 'FontName', fontN, 'FontSize', fontS);
title('(c) Land Use Selectivity', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');

exportgraphics(f3, 'New_Figure_3.png', 'Resolution', 600);

% ----------------------------------------------------------
% NEW FIGURE 4: PROXIMITY, EFFICIENCY, SENSITIVITY (Combines 8, 9, 5)
% ----------------------------------------------------------
f4 = figure('Name', 'New Fig 4: Analysis', 'Color', 'w', 'Position', [100 100 1500 450]);

% Panel A: Safety Buffer
ax6 = subplot(1, 3, 1);
imagesc(Safety_Map); 
risk_cmap = [0.1 0.1 0.1; 1 0 0; 1 1 0; 0 1 0]; colormap(ax6, risk_cmap);
axis(ax6, 'image'); axis(ax6, 'off');
title('(a) Coastal Safety Buffer', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
c6 = colorbar(ax6, 'Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', '<500m (Risk)', '500-1500m', '>1.5km'});
c6.FontName = fontN; c6.FontSize = fontS;

% Panel B: Economic Efficiency
ax7 = subplot(1, 3, 2);
imagesc(Economic_Map); 
econ_cmap = [0.1 0.1 0.1; 0.8 0.2 0.2; 0.9 0.8 0.1; 0 0.8 0.2]; colormap(ax7, econ_cmap);
axis(ax7, 'image'); axis(ax7, 'off');
title('(b) Economic Efficiency', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
c7 = colorbar(ax7, 'Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', 'Low Eff.', 'Mod Eff.', 'High Eff.'});

% ==========================================================
% INDEPENDENT, FULLY RESIZABLE AXES (NO SUBPLOTS)
% ==========================================================
disp('Generating Fully Independent Resizable Figure 3...');

fontN = 'Arial';
fontS = 8;
scale_len_5km = 500; 

f3 = figure('Name', 'New Fig 3: Morphology', 'Color', 'w', 'Position', [100 100 1500 450]);

% ----------------------------------------------------------
% Panel A: Raw Pixels (Independent Axes)
% ----------------------------------------------------------
% 1. Create a completely independent axis (no subplot grid)
ax3 = axes('Parent', f3, 'Position', [0.05, 0.15, 0.25, 0.75]); 
h1 = imagesc(Zoom_Map, 'Parent', ax3); 
colormap(ax3, jet); caxis(ax3, [0 1]);

% 2. THE FIX: Keep axis ON to catch clicks, but make it look invisible (white borders)
set(ax3, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax3, 'normal'); % Unlock aspect ratio
set(ax3, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% 3. Pass mouse clicks through the image directly to the axes
set(h1, 'HitTest', 'off', 'PickableParts', 'none'); 

title(ax3, '(a) Raw Pixel Fragmentation', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');
hold(ax3, 'on'); 
h_line1 = plot(ax3, [20 120], [180 180], 'w-', 'LineWidth', 3);
h_text1 = text(ax3, 70, 170, '1 km', 'FontName', fontN, 'FontSize', fontS, 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
set(h_line1, 'HitTest', 'off', 'PickableParts', 'none');
set(h_text1, 'HitTest', 'off', 'PickableParts', 'none');

% ----------------------------------------------------------
% Panel B: Filtered Contiguous Sites (Independent Axes)
% ----------------------------------------------------------
% 1. Create independent axis
ax4 = axes('Parent', f3, 'Position', [0.35, 0.15, 0.25, 0.75]); 
h2 = imagesc(dem_grid, 'Parent', ax4); 
colormap(ax4, gray); hold(ax4, 'on');

green_overlay = cat(3, zeros(size(dem_grid)), ones(size(dem_grid)), zeros(size(dem_grid)));
h3 = image(green_overlay, 'Parent', ax4); 
set(h3, 'AlphaData', Large_Site_Map);

% 2. THE FIX: Keep axis ON to catch clicks, but make it look invisible
set(ax4, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax4, 'normal'); % Unlock aspect ratio
set(ax4, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% 3. Pass mouse clicks through the layers
set(h2, 'HitTest', 'off', 'PickableParts', 'none');
set(h3, 'HitTest', 'off', 'PickableParts', 'none');

title(ax4, '(b) Filtered Contiguous Sites (>1ha)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');
h_line2 = plot(ax4, [500 500+scale_len_5km], [rows-500 rows-500], 'w-', 'LineWidth', 3);
h_text2 = text(ax4, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'Color', 'w', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
set(h_line2, 'HitTest', 'off', 'PickableParts', 'none');
set(h_text2, 'HitTest', 'off', 'PickableParts', 'none');

% ----------------------------------------------------------
% Panel C: Land Use Bar Chart (Independent Axes)
% ----------------------------------------------------------
% 1. Create independent axis
ax5 = axes('Parent', f3, 'Position', [0.65, 0.15, 0.28, 0.75]); 
data_matrix = [gen_pct; opt_pct]';
b = bar(ax5, data_matrix, 'grouped');
b(1).FaceColor = [0.6 0.6 0.6]; b(1).EdgeColor = 'none';
b(2).FaceColor = [0.1 0.5 0.2]; b(2).EdgeColor = 'none';
grid(ax5, 'on'); set(ax5, 'FontName', fontN, 'FontSize', fontS);
ylabel(ax5, 'Land Composition (%)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
xticklabels(ax5, {'Open Space', 'Low Intensity', 'Med Intensity', 'High Int.'});
legend(ax5, {'Regional Availability', 'Model Selection'}, 'Location', 'NorthWest', 'FontName', fontN, 'FontSize', fontS);
title(ax5, '(c) Land Use Selectivity', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');

disp('Success: Subplots removed. Click the Edit Plot arrow and click directly on a map. All 8 anchor points will appear.');


% ==========================================================
% INDEPENDENT, FULLY RESIZABLE AXES (FIG 2 & FIG 4)
% ==========================================================
disp('Generating Fully Independent Resizable Figures 2 and 4...');

fontN = 'Arial';
fontS = 8;
scale_len_5km = 500; % 500 pixels * 10m = 5km

%% ----------------------------------------------------------
% NEW FIGURE 2: SUITABILITY & CLIMATE TRAP
% ----------------------------------------------------------
f2 = figure('Name', 'New Fig 2: Suitability & Trap', 'Color', 'w', 'Position', [100 100 1200 500]);

% ----------------------------------------------------------
% Panel A: Suitability
% ----------------------------------------------------------
ax1 = axes('Parent', f2, 'Position', [0.05, 0.15, 0.40, 0.75]);
h1 = imagesc(Final_Map, 'Parent', ax1); 
colormap(ax1, jet); caxis(ax1, [0 1]);

% Draw colorbar BEFORE fixing axis properties
c1 = colorbar(ax1); 
c1.Label.String = 'Suitability Index'; c1.FontName = fontN; c1.FontSize = fontS;

% THE FIX: Keep axis ON, hide borders, unlock ratio
set(ax1, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax1, 'normal');
set(ax1, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% Pass mouse clicks through image
set(h1, 'HitTest', 'off', 'PickableParts', 'none'); 

title(ax1, '(a) Final Suitability Surface', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');
hold(ax1, 'on'); 
h_line1 = plot(ax1, [500 500+scale_len_5km], [rows-500 rows-500], 'k-', 'LineWidth', 3);
h_text1 = text(ax1, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'HorizontalAlignment', 'center', 'Color', 'k', 'FontWeight', 'bold');
set(h_line1, 'HitTest', 'off', 'PickableParts', 'none');
set(h_text1, 'HitTest', 'off', 'PickableParts', 'none');

% ----------------------------------------------------------
% Panel B: Climate Trap
% ----------------------------------------------------------
ax2 = axes('Parent', f2, 'Position', [0.55, 0.15, 0.40, 0.75]);
h2 = imagesc(dem_grid, 'Parent', ax2); 
colormap(ax2, gray); hold(ax2, 'on');

lost_land_mask = (Base_Score >= 0.7) & (Final_Map == 0);
red_overlay = cat(3, ones(size(dem_grid)), zeros(size(dem_grid)), zeros(size(dem_grid)));
h3 = image(red_overlay, 'Parent', ax2); 
set(h3, 'AlphaData', lost_land_mask);

% THE FIX: Keep axis ON, hide borders, unlock ratio
set(ax2, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax2, 'normal');
set(ax2, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% Pass mouse clicks through images
set(h2, 'HitTest', 'off', 'PickableParts', 'none');
set(h3, 'HitTest', 'off', 'PickableParts', 'none');

title(ax2, '(b) Climate Trap (Lost Assets)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');
h_line2 = plot(ax2, [500 500+scale_len_5km], [rows-500 rows-500], 'w-', 'LineWidth', 3);
h_text2 = text(ax2, 500+(scale_len_5km/2), rows-250, '5 km', 'FontName', fontN, 'FontSize', fontS, 'HorizontalAlignment', 'center', 'Color', 'w', 'FontWeight', 'bold');
set(h_line2, 'HitTest', 'off', 'PickableParts', 'none');
set(h_text2, 'HitTest', 'off', 'PickableParts', 'none');

exportgraphics(f2, 'New_Figure_2.png', 'Resolution', 600);


%% ----------------------------------------------------------
% NEW FIGURE 4: PROXIMITY, EFFICIENCY, SENSITIVITY
% ----------------------------------------------------------
f4 = figure('Name', 'New Fig 4: Analysis', 'Color', 'w', 'Position', [100 100 1500 450]);

% ----------------------------------------------------------
% Panel A: Safety Buffer
% ----------------------------------------------------------
ax6 = axes('Parent', f4, 'Position', [0.05, 0.15, 0.25, 0.75]);
h6 = imagesc(Safety_Map, 'Parent', ax6); 
risk_cmap = [0.1 0.1 0.1; 1 0 0; 1 1 0; 0 1 0]; colormap(ax6, risk_cmap);

% Draw colorbar BEFORE fixing axis properties
c6 = colorbar(ax6, 'Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', '<500m (Risk)', '500-1500m', '>1.5km'});
c6.FontName = fontN; c6.FontSize = fontS;

% THE FIX: Keep axis ON, hide borders, unlock ratio
set(ax6, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax6, 'normal');
set(ax6, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% Pass mouse clicks through image
set(h6, 'HitTest', 'off', 'PickableParts', 'none'); 

title(ax6, '(a) Coastal Safety Buffer', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');

% ----------------------------------------------------------
% Panel B: Economic Efficiency
% ----------------------------------------------------------
ax7 = axes('Parent', f4, 'Position', [0.35, 0.15, 0.25, 0.75]);
h7 = imagesc(Economic_Map, 'Parent', ax7); 
econ_cmap = [0.1 0.1 0.1; 0.8 0.2 0.2; 0.9 0.8 0.1; 0 0.8 0.2]; colormap(ax7, econ_cmap);

% Draw colorbar BEFORE fixing axis properties
c7 = colorbar(ax7, 'Ticks', [0.3, 1.1, 1.9, 2.6], 'TickLabels', {'Background', 'Low Eff.', 'Mod Eff.', 'High Eff.'});
c7.FontName = fontN; c7.FontSize = fontS;

% THE FIX: Keep axis ON, hide borders, unlock ratio
set(ax7, 'XTick', [], 'YTick', [], 'XColor', 'w', 'YColor', 'w', 'Color', 'none');
axis(ax7, 'normal');
set(ax7, 'DataAspectRatioMode', 'auto', 'PlotBoxAspectRatioMode', 'auto');

% Pass mouse clicks through image
set(h7, 'HitTest', 'off', 'PickableParts', 'none'); 

title(ax7, '(b) Economic Efficiency', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');

% ----------------------------------------------------------
% Panel C: Sensitivity Plot (Standard Line Plot)
% ----------------------------------------------------------
ax8 = axes('Parent', f4, 'Position', [0.68, 0.15, 0.28, 0.75]);
hold(ax8, 'on');
x_conf = [slope_weights, fliplr(slope_weights)];
y_conf = [lower_bound, fliplr(upper_bound)];
fill(ax8, x_conf, y_conf, [0.85 0.85 1], 'EdgeColor', 'none', 'FaceAlpha', 0.5); 
plot(ax8, slope_weights, mean_results, '-bo', 'LineWidth', 2, 'MarkerFaceColor', 'b', 'MarkerSize', 5);
xline(ax8, 0.6, '--k', 'Threshold', 'LabelVerticalAlignment', 'bottom', 'FontName', fontN, 'FontSize', fontS);
grid(ax8, 'on'); set(ax8, 'FontName', fontN, 'FontSize', fontS);
xlabel(ax8, 'Slope Weight (W_s)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
ylabel(ax8, 'Total Suitable Area (km^2)', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold');
title(ax8, '(c) Sensitivity Analysis', 'FontName', fontN, 'FontSize', fontS, 'FontWeight', 'bold', 'Color', 'k');
legend(ax8, {'Stability Range (\pm5%)', 'Mean Suitability'}, 'Location', 'NorthWest', 'FontName', fontN, 'FontSize', fontS);

exportgraphics(f4, 'New_Figure_4.png', 'Resolution', 600);
disp('Success: Subplots completely removed. All maps in Figures 2 & 4 have 8 anchor points for free resizing.');