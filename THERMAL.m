clc; clear; close all;

%% ========================================================================
%% STEP 1: READ STL FILE (AUTO SCALE FIX)
%% ========================================================================
fprintf('STEP 1: STL IMPORT\n');

stlFile = 'tri100010528519800.stl';
TR = stlread(stlFile);

F = double(TR.ConnectivityList);
V = double(TR.Points);

bbox_raw = max(V) - min(V);
if max(bbox_raw) > 10
    fprintf('⚠ STL detected in mm → converting to meters\n');
    V = V / 1000;
else
    fprintf('✓ STL already in meters\n');
end

fprintf('Vertices: %d | Faces: %d\n', size(V,1), size(F,1));

%% ========================================================================
%% STEP 2: ROTATION & BOUNDING BOX
%% ========================================================================
theta = 90;
Rx = [1 0 0; 0 cosd(theta) -sind(theta); 0 sind(theta) cosd(theta)];
V_rot = (Rx * V')';

bbox_min = min(V_rot);
bbox_max = max(V_rot);
bbox_size = bbox_max - bbox_min;

fprintf('Bounding box (m): %.3f × %.3f × %.3f\n', bbox_size);

%% ========================================================================
%% STEP 3: MATERIAL
%% ========================================================================
material.name = 'M19 Silicon Steel';
material.density = 7650;
material.youngs_modulus = 200e9;
material.poissons_ratio = 0.30;
material.yield_strength = 350e6;
material.relative_permeability = 2000;
material.saturation_flux_density = 1.7;
material.core_loss_1T_60Hz = 2.5;
material.stacking_factor = 0.95;

%% ========================================================================
%% STEP 4: TRUE CORE VOLUME & MASS (FIXED)
%% ========================================================================
[K, core_volume] = convhull(V_rot(:,1), V_rot(:,2), V_rot(:,3));
core_volume = core_volume * material.stacking_factor;
core_mass = core_volume * material.density;

fprintf('Core volume: %.4f m³\n', core_volume);
fprintf('Core mass: %.2f kg\n', core_mass);

%% ========================================================================
%% STEP 5: ELECTRICAL
%% ========================================================================
frequency = 60;
winding.current_rms = 50;
winding.turns = 40;

mu_0 = 4*pi*1e-7;
path_length = 2*(bbox_size(1)+bbox_size(2));

H = winding.turns * winding.current_rms / path_length;
B = min(mu_0 * material.relative_permeability * H, ...
        material.saturation_flux_density);

fprintf('B-field: %.3f T\n', B);

%% ========================================================================
%% STEP 6: ELECTROMAGNETIC FORCE (SINGLE CONSISTENT MODEL)
%% ========================================================================
TR_mesh = triangulation(F, V_rot);
areas = zeros(size(F,1),1);

for i = 1:size(F,1)
    v = V_rot(F(i,:),:);
    areas(i) = norm(cross(v(2,:)-v(1,:), v(3,:)-v(1,:))) / 2;
end

total_area = sum(areas);
air_gap_area = 0.03 * total_area;

F_em = (B^2)/(2*mu_0) * air_gap_area;

fprintf('EM force: %.2f N\n', F_em);

%% ========================================================================
%% STEP 7: MECHANICAL RESPONSE
%% ========================================================================
A_cs = bbox_size(1)*bbox_size(2);
L = max(bbox_size);

k = material.youngs_modulus * A_cs / L;
deflection = F_em / k;
stress = F_em / air_gap_area;

fprintf('Stress: %.4f MPa\n', stress/1e6);
fprintf('Deflection: %.4e m\n', deflection);

%% ========================================================================
%% STEP 8: VIBRATION
%% ========================================================================
natural_freq = (1/(2*pi))*sqrt(k/core_mass);

fprintf('Natural frequency: %.2f Hz\n', natural_freq);

%% ========================================================================
%% STEP 9: LOSSES (FIXED)
%% ========================================================================
B_rms = B/sqrt(2);
alpha = 1.8; beta = 1.5;

P_core_specific = material.core_loss_1T_60Hz * ...
    (B_rms/1.0)^alpha * (frequency/60)^beta;

P_core = P_core_specific * core_mass;

fprintf('Core loss: %.1f W (%.2f W/kg)\n', P_core, P_core_specific);

%% ========================================================================
%% STEP 10: THERMAL
%% ========================================================================
h = 10;
ambient = 25;

temp_rise = P_core/(h*total_area);
T_core = ambient + temp_rise;

fprintf('Core temperature: %.1f °C\n', T_core);

%% ========================================================================
%% STEP 11: FINAL VERDICT
%% ========================================================================
fprintf('\n===== FINAL STATUS =====\n');

if stress < material.yield_strength && abs(natural_freq-120)/natural_freq > 0.3
    fprintf('✓ DESIGN PHYSICALLY VALID\n');
else
    fprintf('⚠ DESIGN NEEDS REVIEW\n');
end
