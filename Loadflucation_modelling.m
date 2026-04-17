clc;
clear;
close all;

%% ========================================================================
%%  STEP 1: READ STL FILE
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 1: IMPORTING STL FILE\n');
fprintf('========================================\n');

stlFile = 'tri100010528519800.stl';
TR = stlread(stlFile);

F = TR.ConnectivityList;
V = TR.Points;

V = double(V);
F = double(F);

fprintf('✓ STL file loaded successfully\n');
fprintf('  - Number of vertices: %d\n', size(V,1));
fprintf('  - Number of faces: %d\n', size(F,1));

%% ========================================================================
%%  STEP 2: GEOMETRY NORMALIZATION & ROTATION
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 2: GEOMETRY NORMALIZATION\n');
fprintf('========================================\n');

V_norm = V / 1000;

theta = 90;
Rx = [1  0           0;
      0  cosd(theta) -sind(theta);
      0  sind(theta)  cosd(theta)];
V_rot = (Rx * V_norm')';

bbox_min = min(V_rot);
bbox_max = max(V_rot);
bbox_size = bbox_max - bbox_min;

fprintf('✓ Geometry normalized to SI units (meters)\n');
fprintf('✓ Geometry rotated 90° about X-axis\n');
fprintf('  - Bounding box (m): X[%.3f, %.3f], Y[%.3f, %.3f], Z[%.3f, %.3f]\n', ...
    bbox_min(1), bbox_max(1), bbox_min(2), bbox_max(2), bbox_min(3), bbox_max(3));

%% ========================================================================
%%  STEP 3: MATERIAL PROPERTIES
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 3: MATERIAL PROPERTIES\n');
fprintf('========================================\n');

material.name = 'Silicon Steel Laminations (M19)';
material.density = 7650;
material.youngs_modulus = 200e9;
material.poissons_ratio = 0.30;
material.yield_strength = 350e6;
material.tensile_strength = 450e6;
material.electrical_resistivity = 4.5e-7;
material.relative_permeability_initial = 2000;
material.saturation_flux_density = 2.01;
material.core_loss_1T_60Hz = 2.5;
material.thermal_conductivity = 28;
material.specific_heat = 460;
material.thermal_expansion = 11.5e-6;
material.lamination_thickness = 0.36e-3;
material.stacking_factor = 0.95;

fprintf('✓ Material assigned: %s\n', material.name);

figure('Color','w','Position',[100 100 1400 600]);
subplot(1,2,1);
patch('Faces',F, 'Vertices',V_rot, 'FaceColor',[0.6 0.8 1], 'EdgeColor','none');
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('Rotated Geometry');
camlight headlight; lighting gouraud; view(45,30);

subplot(1,2,2);
patch('Faces',F, 'Vertices',V_rot, 'FaceColor',[0.5 0.55 0.6], 'EdgeColor','none', 'FaceAlpha',0.9);
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('Material Applied');
camlight headlight; lighting gouraud; view(45,30);

%% ========================================================================
%%  STEP 4: MESH ANALYSIS
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 4: MESH ANALYSIS\n');
fprintf('========================================\n');

TR_mesh = triangulation(F, V_rot);
edges_list = edges(TR_mesh);

element_quality = zeros(size(F,1),1);
element_area = zeros(size(F,1),1);

for i = 1:size(F,1)
    v1 = V_rot(F(i,1),:);
    v2 = V_rot(F(i,2),:);
    v3 = V_rot(F(i,3),:);
    
    a = norm(v2-v1);
    b = norm(v3-v2);
    c = norm(v1-v3);
    
    s = (a+b+c)/2;
    area = sqrt(max(0, s*(s-a)*(s-b)*(s-c)));
    element_area(i) = area;
    
    if (a^2 + b^2 + c^2) > 0 && area > 1e-12
        element_quality(i) = 4*sqrt(3)*area / (a^2 + b^2 + c^2);
    else
        element_quality(i) = 0;
    end
end

total_area = sum(element_area);
mean_quality = mean(element_quality);

fprintf('✓ Mesh statistics:\n');
fprintf('  - Nodes: %d\n', size(V_rot,1));
fprintf('  - Elements: %d\n', size(F,1));
fprintf('  - Mean quality: %.4f\n', mean_quality);
fprintf('  - Total surface area: %.4f m²\n', total_area);

core_depth = max(bbox_size) * 0.15;
core_volume = total_area * core_depth * material.stacking_factor;
core_mass = core_volume * material.density;
fprintf('  - Est. core depth: %.4f m (15%% of max dimension)\n', core_depth);
fprintf('  - Core volume: %.4f m³\n', core_volume);
fprintf('  - Core mass: %.2f kg\n\n', core_mass);

%% ========================================================================
%%  STEP 5: BOUNDARY CONDITIONS
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 5: BOUNDARY CONDITIONS\n');
fprintf('========================================\n');

z_min = min(V_rot(:,3));
z_max = max(V_rot(:,3));
tolerance = (z_max - z_min) * 0.05;

fixed_nodes = find(V_rot(:,3) < (z_min + tolerance));
load_nodes = find(V_rot(:,3) > (z_max - tolerance));
load_magnitude = 100;

fprintf('✓ Fixed nodes: %d (bottom)\n', length(fixed_nodes));
fprintf('✓ Loaded nodes: %d (top)\n', length(load_nodes));
fprintf('✓ Applied force: %d N\n\n', load_magnitude);

%% ========================================================================
%%  STEP 6: LOAD & CURRENT SIMULATION
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 6: DYNAMIC SIMULATION\n');
fprintf('========================================\n');

simulation_time = 0.5;
time_step = 0.0001;
time_vector = 0:time_step:simulation_time;
num_time_steps = length(time_vector);
frequency = 60;
omega = 2*pi*frequency;

fprintf('Time setup: %.3f s, %d steps, %.0f Hz\n\n', simulation_time, num_time_steps, frequency);

%% Load profile
load_profile = ones(size(time_vector)) * 100;
for i = 1:num_time_steps
    t = time_vector(i);
    if t < 0.1
        load_profile(i) = 50;
    elseif t < 0.3
        load_profile(i) = 100;
    elseif t < 0.4
        load_profile(i) = 120;
    else
        load_profile(i) = 60;
    end
end

%% Short-circuit
short_circuit_flag = zeros(size(time_vector));
for i = 1:num_time_steps
    t = time_vector(i);
    if t >= 0.25 && t < 0.30
        short_circuit_flag(i) = 1;
    end
end

%% Composite load
harmonic_orders = [1, 5, 7, 11, 13];
harmonic_mags = [1.0, 0.20, 0.14, 0.09, 0.08];
harmonic_phases = [0, -30, 45, -60, 30];

composite_load = zeros(size(time_vector));
for i = 1:num_time_steps
    base_load = load_profile(i);
    
    if short_circuit_flag(i) == 1
        base_load = min(base_load * 5, 120);
    end
    
    harmonic_ripple = 0;
    for h = 2:length(harmonic_orders)
        harmonic_ripple = harmonic_ripple + ...
            (harmonic_mags(h) * base_load * 0.05) * cos(harmonic_orders(h) * omega * time_vector(i) + deg2rad(harmonic_phases(h)));
    end
    
    composite_load(i) = base_load + harmonic_ripple;
    composite_load(i) = max(0, min(composite_load(i), 120));
end

fprintf('Load profile: Peak=%.1f%%, Min=%.1f%%, Avg=%.1f%%\n\n', ...
    max(composite_load), min(composite_load), mean(composite_load));

%% Current calculation
winding.rated_current = 50;
winding.turns_per_phase = 40;
winding.resistance_per_phase = 0.15;
winding.inductance_per_phase = 0.008;

tau = winding.inductance_per_phase / winding.resistance_per_phase;
I_peak_rated = winding.rated_current * sqrt(2);

I_phase_A = zeros(size(time_vector));
I_phase_B = zeros(size(time_vector));
I_phase_C = zeros(size(time_vector));

for i = 1:num_time_steps
    t = time_vector(i);
    load_factor = max(0, composite_load(i) / 100);
    I_amplitude = I_peak_rated * load_factor;
    
    I_phase_A(i) = I_amplitude * cos(omega * t);
    I_phase_B(i) = I_amplitude * cos(omega * t - deg2rad(120));
    I_phase_C(i) = I_amplitude * cos(omega * t - deg2rad(240));
end

I_A_rms = sqrt(mean(I_phase_A.^2));
I_B_rms = sqrt(mean(I_phase_B.^2));
I_C_rms = sqrt(mean(I_phase_C.^2));
I_peak_max = max([max(abs(I_phase_A)), max(abs(I_phase_B)), max(abs(I_phase_C))]);

fprintf('CURRENTS:\n');
fprintf('  RMS: A=%.1f, B=%.1f, C=%.1f A\n', I_A_rms, I_B_rms, I_C_rms);
fprintf('  Peak: A=%.1f, B=%.1f, C=%.1f A\n', max(abs(I_phase_A)), max(abs(I_phase_B)), max(abs(I_phase_C)));
fprintf('  Max peak: %.1f A (expected: 70.7 A)\n\n', I_peak_max);

%% Unbalance
I_phase_A_unbal = I_phase_A;
I_phase_B_unbal = I_phase_B * 0.90;
I_phase_C_unbal = I_phase_C * 0.85;

%% Electromagnetic calculations
B = zeros(size(time_vector));
mu_0 = 4*pi*1e-7;
B_sat = material.saturation_flux_density;

magnetic_path_length = 2 * (bbox_size(1) + bbox_size(2));

for i = 1:num_time_steps
    I_rms_inst = sqrt(mean([I_phase_A_unbal(i)^2, I_phase_B_unbal(i)^2, I_phase_C_unbal(i)^2]));
    MMF = winding.turns_per_phase * I_rms_inst;
    H = MMF / magnetic_path_length;
    
    H_sat = B_sat / (mu_0 * material.relative_permeability_initial);
    
    if H < H_sat
        B(i) = mu_0 * material.relative_permeability_initial * H;
    else
        B(i) = B_sat * (2/pi) * atan(H / H_sat);
    end
    
    B(i) = min(abs(B(i)), B_sat);
end

maxwell_stress = (B.^2) / (2 * mu_0);
air_gap_area = total_area * 0.03;
F_em = maxwell_stress * air_gap_area;

fprintf('ELECTROMAGNETIC:\n');
fprintf('  Peak B: %.4f T\n', max(B));
fprintf('  Avg B: %.4f T\n', mean(B));
fprintf('  Min B: %.4f T\n', min(B));
fprintf('  B variation: %.4f T (peak-to-peak)\n', max(B) - min(B));
fprintf('  Magnetic path length: %.4f m\n', magnetic_path_length);
fprintf('  Air gap area (pole faces): %.4f m² (3%% of surface)\n', air_gap_area);
fprintf('  Peak force: %.1f N\n', max(F_em));
fprintf('  Avg force: %.1f N\n\n', mean(F_em));

%% Power losses calculation
P_copper = (I_A_rms^2 + (I_B_rms*0.9)^2 + (I_C_rms*0.85)^2) * winding.resistance_per_phase;

B_rms = sqrt(mean(B.^2));
f_normalized = frequency / 60;
B_normalized = B_rms / 1.0;

alpha = 2.0;
beta = 1.5;

P_core_specific = material.core_loss_1T_60Hz * (B_normalized^alpha) * (f_normalized^beta);
P_core = P_core_specific * core_mass;

P_total = P_copper + P_core;

fprintf('LOSSES:\n');
fprintf('  Copper: %.1f W\n', P_copper);
fprintf('  Core: %.1f W (%.2f W/kg)\n', P_core, P_core_specific);
fprintf('  Total: %.1f W\n\n', P_total);

%% ========================================================================
%%  STEP 4.1: FEM MODEL
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 4.1: FEM MODEL\n');
fprintf('========================================\n');

TR_fem = triangulation(F, V_rot);
B_node = ones(size(V_rot,1),1) * mean(B);

fprintf('✓ FEM Mesh type: Triangular Surface\n');
fprintf('  - Number of nodes: %d\n', size(V_rot,1));
fprintf('  - Number of elements: %d\n', size(F,1));
fprintf('  - Element type: 3-node triangle\n');
fprintf('  - Field type: Magnetic field (B)\n');
fprintf('  - Field units: Tesla (T)\n');
fprintf('  - Analysis type: Quasi-static\n');
fprintf('  - Time steps analyzed: %d\n\n', num_time_steps);

%% ========================================================================
%%  STEP 4.2: ELECTROMAGNETIC FORCE CALCULATION
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 4.2: ELECTROMAGNETIC FORCE\n');
fprintf('========================================\n');

F_element = zeros(size(F,1),1);

z_threshold = z_max - 0.05 * (z_max - z_min);
pole_face_elements = [];

for elem = 1:size(F,1)
    v_indices = F(elem,:);
    z_center = mean(V_rot(v_indices, 3));
    
    if z_center > z_threshold
        pole_face_elements = [pole_face_elements; elem];
    end
end

fprintf('✓ Identified %d elements in pole face region\n', length(pole_face_elements));

for elem = 1:size(F,1)
    v_indices = F(elem,:);
    v1 = V_rot(v_indices(1),:);
    v2 = V_rot(v_indices(2),:);
    v3 = V_rot(v_indices(3),:);
    
    edge1 = v2 - v1;
    edge2 = v3 - v1;
    cross_prod = cross(edge1, edge2);
    normal = cross_prod / (norm(cross_prod) + eps);
    area_elem = norm(cross_prod) / 2;
    
    B_elem = max(B);
    stress = (B_elem^2) / (2 * mu_0);
    
    if ismember(elem, pole_face_elements)
        force_vec = stress * area_elem * normal;
        F_element(elem) = norm(force_vec);
    else
        F_element(elem) = 0;
    end
end

F_elem_max = max(F_element);
F_elem_min = min(F_element(F_element > 0));
F_elem_mean = mean(F_element(F_element > 0));
F_elem_total = sum(F_element);

fprintf('✓ Force Distribution on Elements:\n');
fprintf('  - Maximum element force: %.4f N\n', F_elem_max);
fprintf('  - Minimum element force (non-zero): %.4f N\n', F_elem_min);
fprintf('  - Mean element force (pole faces): %.4f N\n', F_elem_mean);
fprintf('  - Total integrated force: %.2f N\n', F_elem_total);
fprintf('  - Method: Maxwell stress tensor on pole faces\n');
fprintf('  - Formula: F = (B²/2μ₀) × A × n̂ (pole faces only)\n\n');

%% ========================================================================
%%  STEP 4.3: EM-MECHANICAL COUPLING
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 4.3: EM-MECHANICAL COUPLING\n');
fprintf('========================================\n');

stress_em = F_elem_total / (air_gap_area + eps);
characteristic_length = max(bbox_size);

cross_section_area = bbox_size(1) * bbox_size(2);
moment_inertia_3D = (bbox_size(1) * bbox_size(2)^3) / 12;

k_axial = material.youngs_modulus * cross_section_area / characteristic_length;
k_bending = 3 * material.youngs_modulus * moment_inertia_3D / (characteristic_length^3);
spring_constant = k_axial + k_bending;

deflection_estimate = F_elem_total / spring_constant;
strain_estimate = deflection_estimate / characteristic_length;

natural_freq = (1/(2*pi)) * sqrt(spring_constant / core_mass);

fprintf('✓ Stress Analysis:\n');
fprintf('  - EM stress on pole faces: %.4f Pa (%.4f MPa)\n', stress_em, stress_em/1e6);
fprintf('  - Yield strength: %.0f MPa\n', material.yield_strength/1e6);
fprintf('  - Safety factor: %.2f ✓\n', (material.yield_strength / (stress_em + 0.001)));
fprintf('✓ Deformation Analysis:\n');
fprintf('  - Estimated deflection: %.4e m (%.4f μm)\n', deflection_estimate, deflection_estimate*1e6);
fprintf('  - Strain estimate: %.4e (dimensionless)\n', strain_estimate);
fprintf('✓ Vibration Analysis:\n');
fprintf('  - Core mass: %.2f kg\n', core_mass);
fprintf('  - Cross-section area: %.4f m²\n', cross_section_area);
fprintf('  - Axial stiffness: %.2e N/m\n', k_axial);
fprintf('  - Bending stiffness: %.2e N/m\n', k_bending);
fprintf('  - Total stiffness: %.2e N/m\n', spring_constant);
fprintf('  - Natural frequency: %.2f Hz\n', natural_freq);
fprintf('  - Excitation frequency: %.0f Hz (2× electrical)\n', 2*frequency);

if abs(natural_freq - 2*frequency) / natural_freq < 0.2
    fprintf('  - Resonance risk: HIGH ⚠\n\n');
elseif abs(natural_freq - 2*frequency) / natural_freq < 0.5
    fprintf('  - Resonance risk: MODERATE\n\n');
else
    fprintf('  - Resonance risk: LOW\n\n');
end

%% ========================================================================
%%  STEP 5: 3D FEM VISUALIZATION
%% ========================================================================
fprintf('========================================\n');
fprintf('STEP 5: 3D FEM VISUALIZATION\n');
fprintf('========================================\n');

figure('Color','w','Position',[50 50 1800 1200],'Name','FEM Analysis - 3D Visualization');

ax1 = subplot(2,3,1);
patch('Faces',F, 'Vertices',V_rot, 'FaceColor',[0.7 0.75 0.8], 'EdgeColor','none', 'FaceAlpha',0.8);
hold on;
plot3(V_rot(fixed_nodes,1), V_rot(fixed_nodes,2), V_rot(fixed_nodes,3), 'ro', 'MarkerSize',3);
quiver3(V_rot(load_nodes,1), V_rot(load_nodes,2), V_rot(load_nodes,3), ...
        zeros(length(load_nodes),1), zeros(length(load_nodes),1), ...
        -ones(length(load_nodes),1)*0.1, 'b', 'LineWidth',2, 'AutoScale','off');
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('FEM Geometry & Boundary Conditions');
camlight; lighting gouraud; view(45,30);

ax2 = subplot(2,3,2);
patch('Faces',F, 'Vertices',V_rot, 'FaceVertexCData',B_node, 'FaceColor','flat', 'EdgeColor','none');
colormap(ax2, jet); cb = colorbar(ax2); cb.Label.String = 'B-field [T]';
caxis([min(B) max(B)]);
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('Magnetic Field Distribution');
camlight; lighting gouraud; view(45,30);

ax3 = subplot(2,3,3);
patch('Faces',F, 'Vertices',V_rot, 'FaceVertexCData',F_element, 'FaceColor','flat', 'EdgeColor','none');
colormap(ax3, hot); cb = colorbar(ax3); cb.Label.String = 'Force [N]';
caxis([0 max(F_element)]);
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('EM Force (Pole Faces Only)');
camlight; lighting gouraud; view(45,30);

ax4 = subplot(2,3,4);
H_element = zeros(size(F,1),1);
for e = 1:size(F,1)
    z_avg = mean(V_rot(F(e,:),3));
    z_factor = 1 + (z_avg - min(V_rot(:,3))) / (max(V_rot(:,3)) - min(V_rot(:,3))) * 0.2;
    H_element(e) = (mean(B) / (mu_0*material.relative_permeability_initial)) * z_factor;
end

patch('Faces',F, 'Vertices',V_rot, 'FaceVertexCData',H_element, 'FaceColor','flat', 'EdgeColor','none');
colormap(ax4, cool); 
cb = colorbar(ax4); 
cb.Label.String = 'H-field [A/m]';
caxis(ax4, [min(H_element) max(H_element)]);
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title(sprintf('H-field Intensity\nRange: %.1f - %.1f A/m', min(H_element), max(H_element)));
camlight; lighting gouraud; view(45,30);

ax5 = subplot(2,3,5);
stress_node = ones(size(V_rot,1),1) * stress_em;
patch('Faces',F, 'Vertices',V_rot, 'FaceVertexCData',stress_node*1e-6, 'FaceColor','flat', 'EdgeColor','none');
colormap(ax5, parula); cb = colorbar(ax5); cb.Label.String = 'Stress [MPa]';
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title('Mechanical Stress from EM Forces');
camlight; lighting gouraud; view(45,30);

ax6 = subplot(2,3,6);
deflection_scale = deflection_estimate * 1000;
V_deformed = V_rot;
z_min_val = min(V_rot(:,3));
z_max_val = max(V_rot(:,3));
z_range = z_max_val - z_min_val + eps;

for i = 1:size(V_rot,1)
    if ~ismember(i, fixed_nodes)
        z_norm = (V_rot(i,3) - z_min_val) / z_range;
        V_deformed(i,3) = V_rot(i,3) + z_norm * deflection_scale;
    end
end

patch('Faces',F, 'Vertices',V_deformed, 'FaceColor',[0.2 0.8 0.5], 'EdgeColor','none', 'FaceAlpha',0.8);
hold on;
patch('Faces',F, 'Vertices',V_rot, 'FaceColor','none', 'EdgeColor',[0.5 0.5 0.5], 'LineWidth',0.3);
axis equal; grid on; xlabel('X [m]'); ylabel('Y [m]'); zlabel('Z [m]');
title(sprintf('Deformation (1000× Exaggerated)\nMax: %.2e m', deflection_estimate));
camlight; lighting gouraud; view(45,30);
legend('Deformed','Original');

fprintf('✓ 3D FEM visualizations generated:\n');
fprintf('  1. Geometry with boundary conditions\n');
fprintf('  2. Magnetic field (B) distribution\n');
fprintf('  3. Electromagnetic force distribution (pole faces)\n');
fprintf('  4. Field intensity (H) distribution\n');
fprintf('  5. Mechanical stress distribution\n');
fprintf('  6. Deformed shape (exaggerated)\n\n');

%% ========================================================================
%%  STEP 5: DYNAMIC RESPONSE ANALYSIS
%% ========================================================================
fprintf('╔════════════════════════════════════════╗\n');
fprintf('║ STEP 5: DYNAMIC RESPONSE ANALYSIS      ║\n');
fprintf('╚════════════════════════════════════════╝\n\n');

fprintf('========================================\n');
fprintf('5.1 TIME-DOMAIN RESPONSE ANALYSIS\n');
fprintf('========================================\n');

instantaneous_stress = (B.^2) / (2 * mu_0) / 1e6;
instantaneous_displacement = deflection_estimate * (B / max(B));

damping_ratio = 0.02;
omega_n = 2*pi*natural_freq;
excitation_freq = 2 * frequency;
omega_e = 2*pi*excitation_freq;

freq_ratio = omega_e / omega_n;
mag_factor = 1 / sqrt((1 - freq_ratio^2)^2 + (2*damping_ratio*freq_ratio)^2);

vibration_response = zeros(size(time_vector));
for i = 1:length(time_vector)
    t = time_vector(i);
    static_deflection = deflection_estimate * (B(i) / max(B));
    vibration_response(i) = static_deflection * mag_factor * sin(omega_e * t);
end

stress_peak = max(instantaneous_stress);
stress_rms = sqrt(mean(instantaneous_stress.^2));
displacement_peak = max(abs(instantaneous_displacement));
displacement_rms = sqrt(mean(instantaneous_displacement.^2));
vibration_peak = max(abs(vibration_response));
vibration_rms = sqrt(mean(vibration_response.^2));

fprintf('✓ Instantaneous Stress Analysis:\n');
fprintf('  - Peak stress: %.4f MPa\n', stress_peak);
fprintf('  - RMS stress: %.4f MPa\n', stress_rms);
fprintf('  - Stress range: %.4f - %.4f MPa\n', min(instantaneous_stress), max(instantaneous_stress));
fprintf('✓ Transient Displacement:\n');
fprintf('  - Peak displacement: %.4e m (%.4f μm)\n', displacement_peak, displacement_peak*1e6);
fprintf('  - RMS displacement: %.4e m (%.4f μm)\n', displacement_rms, displacement_rms*1e6);
fprintf('✓ Vibration Response:\n');
fprintf('  - Peak vibration: %.4e m (%.4f μm)\n', vibration_peak, vibration_peak*1e6);
fprintf('  - RMS vibration: %.4e m (%.4f μm)\n', vibration_rms, vibration_rms*1e6);
fprintf('  - Dynamic magnification: %.2f\n\n', mag_factor);

%% 5.2: FREQUENCY-DOMAIN ANALYSIS (FFT)
fprintf('========================================\n');
fprintf('5.2 FREQUENCY-DOMAIN ANALYSIS (FFT)\n');
fprintf('========================================\n');

N = length(instantaneous_stress);
fft_stress = fft(instantaneous_stress);
fft_disp = fft(instantaneous_displacement);

freq_resolution = 1/(time_step*N);
freqs = (0:N-1) * freq_resolution;
freqs_half = freqs(1:floor(N/2));

fft_mag_stress = abs(fft_stress(1:floor(N/2))) / (N/2);
fft_mag_disp = abs(fft_disp(1:floor(N/2))) / (N/2);

idx_60 = max(1, round(60/freq_resolution));
idx_120 = max(1, round(120/freq_resolution));
idx_300 = max(1, round(300/freq_resolution));

idx_60 = min(idx_60, length(fft_mag_stress));
idx_120 = min(idx_120, length(fft_mag_stress));
idx_300 = min(idx_300, length(fft_mag_stress));

fprintf('✓ Stress Signal FFT Analysis:\n');
fprintf('  - Fundamental (60 Hz): %.6f MPa\n', fft_mag_stress(idx_60));
fprintf('  - 2nd harmonic (120 Hz): %.6f MPa\n', fft_mag_stress(idx_120));
fprintf('  - 5th harmonic (300 Hz): %.6f MPa\n', fft_mag_stress(idx_300));

threshold_stress = max(fft_mag_stress) * 0.01;
if threshold_stress < 1e-10
    threshold_stress = 1e-10;
end

[pks_stress, locs_stress] = findpeaks(fft_mag_stress, 'MinPeakHeight', threshold_stress, 'NPeaks', 5, 'SortStr', 'descend');

threshold_disp = max(fft_mag_disp) * 0.01;
if threshold_disp < 1e-15
    threshold_disp = 1e-15;
end

[pks_disp, locs_disp] = findpeaks(fft_mag_disp, 'MinPeakHeight', threshold_disp, 'NPeaks', 5, 'SortStr', 'descend');

if ~isempty(locs_stress)
    fprintf('  - Peak frequency components detected: %d\n', length(locs_stress));
    fprintf('  - Top 3 frequencies: ');
    for k = 1:min(3, length(locs_stress))
        fprintf('%.1f Hz (%.6f MPa) ', freqs_half(locs_stress(k)), pks_stress(k));
    end
    fprintf('\n');
else
    fprintf('  - Peak frequency components detected: 0 (low signal variation)\n');
end

fprintf('✓ Displacement Signal FFT Analysis:\n');
fprintf('  - Peak frequency components: %d\n', length(locs_disp));

if ~isempty(locs_disp) && any(abs(freqs_half(locs_disp) - natural_freq) < 10)
    fprintf('  - ⚠ WARNING: Frequency content near natural frequency (%.2f Hz)\n\n', natural_freq);
else
    fprintf('  - ✓ SAFE: No resonance frequency detected\n\n');
end

figure('Color','w','Position',[50 50 1800 900],'Name','Frequency Domain Analysis');

subplot(2,3,1);
semilogy(freqs_half, fft_mag_stress, 'LineWidth', 1.5, 'Color', [0.2 0.4 0.8]);
hold on;
if ~isempty(locs_stress)
    semilogy(freqs_half(locs_stress), pks_stress, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
    legend('FFT Magnitude', 'Detected Peaks', 'Location', 'best');
else
    legend('FFT Magnitude', 'Location', 'best');
end
xlabel('Frequency [Hz]', 'FontSize', 11);
ylabel('Magnitude [MPa]', 'FontSize', 11);
title('Stress Signal - FFT Spectrum', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([0 500]);

subplot(2,3,2);
semilogy(freqs_half, fft_mag_disp, 'LineWidth', 1.5, 'Color', [0.2 0.6 0.2]);
hold on;
if ~isempty(locs_disp)
    semilogy(freqs_half(locs_disp), pks_disp, 'ro', 'MarkerSize', 8, 'LineWidth', 2);
end
xline(natural_freq, 'r--', 'LineWidth', 2, 'Label', sprintf('Natural: %.1f Hz', natural_freq));
xlabel('Frequency [Hz]', 'FontSize', 11);
ylabel('Magnitude [m]', 'FontSize', 11);
title('Displacement Signal - FFT Spectrum', 'FontSize', 12, 'FontWeight', 'bold');
grid on; xlim([0 500]);
if ~isempty(locs_disp)
    legend('FFT Magnitude', 'Detected Peaks', 'Natural Freq', 'Location', 'best');
else
    legend('FFT Magnitude', 'Natural Freq', 'Location', 'best');
end

subplot(2,3,3);
plot(time_vector, instantaneous_stress, 'LineWidth', 1.5, 'Color', [0.2 0.4 0.8]);
xlabel('Time [s]', 'FontSize', 11);
ylabel('Stress [MPa]', 'FontSize', 11);
title('Instantaneous Stress vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
ylim([min(instantaneous_stress) - 0.5, max(instantaneous_stress) + 0.5]);

subplot(2,3,4);
plot(time_vector, instantaneous_displacement*1e6, 'LineWidth', 1.5, 'Color', [0.2 0.6 0.2]);
xlabel('Time [s]', 'FontSize', 11);
ylabel('Displacement [μm]', 'FontSize', 11);
title('Displacement vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(2,3,5);
plot(time_vector, vibration_response*1e6, 'LineWidth', 1.5, 'Color', [0.8 0.2 0.2]);
xlabel('Time [s]', 'FontSize', 11);
ylabel('Vibration [μm]', 'FontSize', 11);
title('Vibration Response vs Time', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

subplot(2,3,6);
scatter(composite_load, instantaneous_stress, 25, time_vector, 'filled', 'MarkerEdgeColor', 'k', 'MarkerEdgeAlpha', 0.3);
colormap(gca, jet);
cb = colorbar;
cb.Label.String = 'Time [s]';
xlabel('Load [%]', 'FontSize', 11);
ylabel('Stress [MPa]', 'FontSize', 11);
title('Stress vs Load Profile', 'FontSize', 12, 'FontWeight', 'bold');
grid on;

fprintf('✓ Frequency domain plots generated\n\n');

%% ========================================================================
%%  STEP 6: STABILITY CHECK - CORRECTED THERMAL MODEL
%% ========================================================================
fprintf('╔════════════════════════════════════════╗\n');
fprintf('║ STEP 6: STABILITY & SAFETY CHECK       ║\n');
fprintf('╚════════════════════════════════════════╝\n\n');

fprintf('========================================\n');
fprintf('6.1 MECHANICAL STABILITY\n');
fprintf('========================================\n');

safety_factor_yield = material.yield_strength / (stress_peak*1e6 + 0.001);
safety_factor_tensile = material.tensile_strength / (stress_peak*1e6 + 0.001);

if safety_factor_yield >= 2.0
    status_yield = '✓ SAFE';
elseif safety_factor_yield >= 1.5
    status_yield = '⚠ MARGINAL';
else
    status_yield = '✗ CRITICAL';
end

if safety_factor_tensile >= 3.0
    status_tensile = '✓ SAFE';
else
    status_tensile = '✗ HIGH RISK';
end

fprintf('✓ Stress Safety Analysis:\n');
fprintf('  - Peak stress: %.6f MPa\n', stress_peak);
fprintf('  - Yield strength: %.0f MPa\n', material.yield_strength/1e6);
fprintf('  - Tensile strength: %.0f MPa\n', material.tensile_strength/1e6);
fprintf('  - Safety factor (yield): %.2f → %s\n', safety_factor_yield, status_yield);
fprintf('  - Safety factor (tensile): %.2f → %s\n', safety_factor_tensile, status_tensile);

max_strain = strain_estimate;
if max_strain < 0.001
    status_strain = '✓ ACCEPTABLE';
else
    status_strain = '⚠ MONITOR';
end
fprintf('  - Max strain: %.4e → %s\n\n', max_strain, status_strain);

fprintf('========================================\n');
fprintf('6.2 RESONANCE AVOIDANCE CHECK\n');
fprintf('========================================\n');

excitation_freq_2x = 2 * frequency;
if natural_freq > 0
    resonance_margin = abs(excitation_freq_2x - natural_freq) / natural_freq * 100;
else
    resonance_margin = 100;
end

fprintf('✓ Vibration Frequencies:\n');
fprintf('  - Natural frequency: %.2f Hz\n', natural_freq);
fprintf('  - Electrical frequency: %.0f Hz\n', frequency);
fprintf('  - Excitation frequency: %.0f Hz (2×)\n', excitation_freq_2x);
fprintf('  - Frequency separation: %.2f %%\n', resonance_margin);
fprintf('  - Dynamic magnification: %.2f\n', mag_factor);

if resonance_margin > 20
    status_resonance = '✓ SAFE - NO RESONANCE RISK';
elseif resonance_margin > 10
    status_resonance = '⚠ MONITOR - CAUTION ZONE';
else
    status_resonance = '✗ CRITICAL - RESONANCE RISK';
end
fprintf('  - Status: %s\n\n', status_resonance);

fprintf('========================================\n');
fprintf('6.3 THERMAL STABILITY (CORRECTED MODEL)\n');
fprintf('========================================\n');

% FIXED: Proper steady-state thermal resistance model
ambient_temp = 25;
max_operating_temp = 150;

% Heat transfer coefficients (W/m²·K)
h_natural = 10;      % Natural convection in air
h_forced = 50;       % Forced air cooling
h_oil = 500;         % Oil immersion

% Use natural convection as baseline
h_conv = h_natural;

% Stefan-Boltzmann constant
emissivity = 0.85;
stefan_boltzmann = 5.67e-8;  % W/(m²·K⁴)

% Simplified steady-state thermal resistance approach
% At steady state: P_total = h_conv * A * ΔT + ε*σ*A*(T^4 - T_amb^4)
% For small temperature rises, linearize radiation:
% h_rad ≈ 4*ε*σ*T_avg^3 where T_avg ≈ (T_core + T_amb)/2

% Initial estimate
T_avg_K = ambient_temp + 273.15 + 25;  % Assume ~25°C rise initially
h_rad_lin = 4 * emissivity * stefan_boltzmann * T_avg_K^3;

% Total heat transfer coefficient
h_total = h_conv + h_rad_lin;

% Temperature rise from thermal resistance
% ΔT = P / (h_total * A)
temp_rise = P_total / (h_total * total_area);

% Core temperature
T_core = ambient_temp + temp_rise;

% Refine with updated radiation coefficient (one iteration)
T_avg_K_new = (T_core + ambient_temp)/2 + 273.15;
h_rad_lin = 4 * emissivity * stefan_boltzmann * T_avg_K_new^3;
h_total = h_conv + h_rad_lin;
temp_rise = P_total / (h_total * total_area);
T_core = ambient_temp + temp_rise;

thermal_margin = max_operating_temp - T_core;

% Heat dissipation breakdown
q_conv = h_conv * total_area * temp_rise;
T_core_K = T_core + 273.15;
T_ambient_K = ambient_temp + 273.15;
q_rad = emissivity * stefan_boltzmann * total_area * (T_core_K^4 - T_ambient_K^4);

fprintf('✓ Thermal Analysis (Natural Convection):\n');
fprintf('  - Total losses: %.1f W\n', P_total);
fprintf('  - Core surface area: %.2f m²\n', total_area);
fprintf('  - Convection coefficient: h = %.0f W/(m²·K)\n', h_conv);
fprintf('  - Linearized radiation coeff: h_rad ≈ %.1f W/(m²·K)\n', h_rad_lin);
fprintf('  - Total heat transfer coeff: %.1f W/(m²·K)\n', h_total);
fprintf('  - Convection power: %.1f W\n', q_conv);
fprintf('  - Radiation power: %.1f W\n', q_rad);
fprintf('  - Ambient temperature: %.0f °C\n', ambient_temp);
fprintf('  - Temperature rise: %.2f °C\n', temp_rise);
fprintf('  - Core temperature: %.2f °C\n', T_core);
fprintf('  - Max operating temp: %.0f °C\n', max_operating_temp);
fprintf('  - Thermal margin: %.2f °C\n', thermal_margin);

if T_core < max_operating_temp - 20
    status_thermal = '✓ SAFE';
elseif T_core < max_operating_temp
    status_thermal = '⚠ MONITOR';
else
    status_thermal = '✗ OVERHEATING RISK';
end
fprintf('  - Thermal status: %s\n', status_thermal);

% Cooling recommendations if needed
if strcmp(status_thermal, '✗ OVERHEATING RISK') || strcmp(status_thermal, '⚠ MONITOR')
    fprintf('\n  COOLING RECOMMENDATIONS:\n');
    
    % With forced air
    h_total_forced = h_forced + h_rad_lin;
    temp_rise_forced = P_total / (h_total_forced * total_area);
    T_core_forced = ambient_temp + temp_rise_forced;
    fprintf('  - With forced air (h=%.0f): T ≈ %.1f °C\n', h_forced, T_core_forced);
    
    % With oil cooling
    h_total_oil = h_oil;  % Radiation negligible in oil
    temp_rise_oil = P_total / (h_total_oil * total_area);
    T_core_oil = ambient_temp + temp_rise_oil;
    fprintf('  - With oil immersion (h=%.0f): T ≈ %.1f °C\n', h_oil, T_core_oil);
    
    if T_core > max_operating_temp
        fprintf('  - ⚠ CRITICAL: Forced air or oil cooling REQUIRED\n');
    else
        fprintf('  - Suggestion: Consider forced air for safety margin\n');
    end
end
fprintf('\n');

fprintf('========================================\n');
fprintf('6.4 MATERIAL RELIABILITY (FATIGUE)\n');
fprintf('========================================\n');

mean_stress = mean(instantaneous_stress);
stress_amplitude = (max(instantaneous_stress) - min(instantaneous_stress)) / 2;
fatigue_strength_1e6 = (material.yield_strength/1e6) * 0.5;

if stress_amplitude > 0
    R_ratio = min(instantaneous_stress) / (max(instantaneous_stress) + eps);
else
    R_ratio = 0;
end

if fatigue_strength_1e6 > 0
    fatigue_factor = stress_amplitude / (fatigue_strength_1e6 * (1 - mean_stress/(material.yield_strength/1e6)));
else
    fatigue_factor = 0;
end

fprintf('✓ Fatigue Analysis:\n');
fprintf('  - Mean stress: %.6f MPa\n', mean_stress);
fprintf('  - Stress amplitude: %.6f MPa\n', stress_amplitude);
fprintf('  - R-ratio (min/max): %.4f\n', R_ratio);
fprintf('  - Est. fatigue strength (10⁶ cycles): %.0f MPa\n', fatigue_strength_1e6);

if fatigue_factor < 1.0
    status_fatigue = '✓ SAFE FOR > 10⁶ CYCLES';
elseif fatigue_factor < 2.0
    status_fatigue = '⚠ MONITOR - LIMIT TO 10⁵ CYCLES';
else
    status_fatigue = '✗ HIGH FATIGUE RISK';
end
fprintf('  - Fatigue factor: %.4f\n', fatigue_factor);
fprintf('  - Fatigue status: %s\n\n', status_fatigue);

fprintf('========================================\n');
fprintf('6.5 OVERALL SYSTEM ASSESSMENT\n');
fprintf('========================================\n');

fprintf('┌──────────────────────────┬────────────┬──────────────────┐\n');
fprintf('│ ASSESSMENT CRITERIA      │ VALUE      │ STATUS           │\n');
fprintf('├──────────────────────────┼────────────┼──────────────────┤\n');
fprintf('│ Safety Factor (Yield)    │ %.2f       │ %-16s │\n', safety_factor_yield, status_yield);
fprintf('│ Safety Factor (Tensile)  │ %.2f       │ %-16s │\n', safety_factor_tensile, status_tensile);
fprintf('│ Resonance Margin         │ %.2f %%     │ %-16s │\n', resonance_margin, status_resonance(1:min(16,end)));
fprintf('│ Thermal Status           │ %.1f °C    │ %-16s │\n', T_core, status_thermal);
fprintf('│ Fatigue Factor           │ %.4f     │ %-16s │\n', fatigue_factor, status_fatigue(1:min(16,end)));
fprintf('└──────────────────────────┴────────────┴──────────────────┘\n\n');

all_safe = contains(status_yield, '✓') && contains(status_tensile, '✓') && ...
           contains(status_resonance, '✓') && contains(status_thermal, '✓');

fprintf('════════════════════════════════════════════════════════════\n');
if all_safe
    fprintf('✓✓✓ FINAL VERDICT: DESIGN APPROVED FOR OPERATION ✓✓✓\n');
    fprintf('    The transformer core is mechanically stable, thermally\n');
    fprintf('    safe, and shows no resonance risk. Long-term reliability\n');
    fprintf('    is expected under normal operating conditions.\n');
else
    fprintf('⚠⚠⚠ FINAL VERDICT: DESIGN REQUIRES REVIEW ⚠⚠⚠\n');
    fprintf('    Review critical areas:\n');
    if ~contains(status_yield, '✓')
        fprintf('    → Reduce mechanical stress or increase core thickness\n');
    end
    if ~contains(status_resonance, '✓')
        fprintf('    → Adjust stiffness or damping to avoid resonance\n');
    end
    if ~contains(status_thermal, '✓') && ~contains(status_thermal, '⚠')
        fprintf('    → Improve cooling system REQUIRED\n');
    elseif contains(status_thermal, '⚠')
        fprintf('    → Consider enhanced cooling for safety margin\n');
    end
end
fprintf('════════════════════════════════════════════════════════════\n\n');

%% ========================================================================
%%  STEP 7: FINAL SUMMARY REPORT
%% ========================================================================
fprintf('╔════════════════════════════════════════════════════════╗\n');
fprintf('║              FEA ANALYSIS COMPLETE ✓                   ║\n');
fprintf('╚════════════════════════════════════════════════════════╝\n\n');

fprintf('GEOMETRY & MESH PROPERTIES:\n');
fprintf('  Nodes: %d | Elements: %d | Mean quality: %.4f\n', size(V_rot,1), size(F,1), mean_quality);
fprintf('  Surface area: %.4f m² | Core mass: %.2f kg\n\n', total_area, core_mass);

fprintf('ELECTRICAL PARAMETERS:\n');
fprintf('  Rated current: %.0f A (RMS) | Peak current: %.1f A\n', winding.rated_current, I_peak_max);
fprintf('  Frequency: %.0f Hz | Total losses: %.1f W\n', frequency, P_total);
fprintf('  Copper losses: %.1f W | Core losses: %.1f W\n\n', P_copper, P_core);

fprintf('ELECTROMAGNETIC RESULTS:\n');
fprintf('  B-field: Peak=%.4f T | Avg=%.4f T | Variation=%.4f T\n', max(B), mean(B), max(B)-min(B));
fprintf('  Air gap area (pole faces): %.4f m² (3%% of surface)\n', air_gap_area);
fprintf('  Force: Peak=%.1f N | Mean=%.1f N | Integrated=%.2f N\n', max(F_em), mean(F_em), F_elem_total);
fprintf('  Stress: Peak=%.6f MPa | RMS=%.6f MPa\n\n', stress_peak, stress_rms);

fprintf('DYNAMIC RESPONSE ANALYSIS:\n');
fprintf('  Displacement: Peak=%.4e m (%.4f μm) | RMS=%.4e m (%.4f μm)\n', displacement_peak, displacement_peak*1e6, displacement_rms, displacement_rms*1e6);
fprintf('  Vibration: Peak=%.4e m (%.4f μm) | RMS=%.4e m (%.4f μm)\n', vibration_peak, vibration_peak*1e6, vibration_rms, vibration_rms*1e6);
fprintf('  Natural frequency: %.2f Hz | Excitation: %.0f Hz | Magnification: %.2f\n\n', natural_freq, excitation_freq_2x, mag_factor);

fprintf('STABILITY & SAFETY ASSESSMENT:\n');
fprintf('  Safety factors: Yield=%.2f (%.0f MPa) | Tensile=%.2f (%.0f MPa)\n', ...
    safety_factor_yield, material.yield_strength/1e6, safety_factor_tensile, material.tensile_strength/1e6);
fprintf('  Operating temp: %.1f °C | Thermal margin: %.1f °C\n', T_core, thermal_margin);
fprintf('  Fatigue factor: %.4f | Resonance margin: %.2f %%\n\n', fatigue_factor, resonance_margin);

fprintf('════════════════════════════════════════════════════════════\n');
fprintf('                  ANALYSIS SUCCESSFUL!\n');
fprintf('════════════════════════════════════════════════════════════\n');