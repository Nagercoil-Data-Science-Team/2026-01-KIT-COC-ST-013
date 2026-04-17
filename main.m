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

if isa(TR,'triangulation')
    F = TR.ConnectivityList;
    V = TR.Points;
else
    F = TR.ConnectivityList;
    V = TR.Points;
end

V = double(V);
F = double(F);

fprintf('✓ STL file loaded successfully\n');
fprintf('  - Number of vertices: %d\n', size(V,1));
fprintf('  - Number of faces: %d\n', size(F,1));
fprintf('  - Bounding box: X[%.2f, %.2f], Y[%.2f, %.2f], Z[%.2f, %.2f]\n', ...
    min(V(:,1)), max(V(:,1)), min(V(:,2)), max(V(:,2)), min(V(:,3)), max(V(:,3)));

%% ========================================================================
%%  STEP 2: ROTATE STL TO VERTICAL ORIENTATION
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 2: GEOMETRY TRANSFORMATION\n');
fprintf('========================================\n');

theta = 90;  % degrees
Rx = [1  0           0;
      0  cosd(theta) -sind(theta);
      0  sind(theta)  cosd(theta)];
V_rot = (Rx * V')';

fprintf('✓ Geometry rotated 90° about X-axis\n');
fprintf('  - New bounding box: X[%.2f, %.2f], Y[%.2f, %.2f], Z[%.2f, %.2f]\n', ...
    min(V_rot(:,1)), max(V_rot(:,1)), min(V_rot(:,2)), max(V_rot(:,2)), ...
    min(V_rot(:,3)), max(V_rot(:,3)));

% Plot original STL
figure('Color','w','Position',[100 100 1400 600]);
subplot(1,2,1);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.6 0.8 1], 'EdgeColor','none');
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Step 2: Rotated Geometry');
camlight headlight; lighting gouraud;
view(45,30);

%% ========================================================================
%%  STEP 3: MATERIAL PROPERTY ASSIGNMENT - SILICON STEEL LAMINATIONS
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 3: MATERIAL PROPERTIES\n');
fprintf('========================================\n');

% Define material properties for Silicon Steel Laminations (M19 Grade)
% Commonly used in electrical machines (motors, transformers, generators)
material.name = 'Silicon Steel Laminations (M19)';
material.grade = 'M19 (3% Si-Fe)';
material.type = 'Electrical Steel';

% Mechanical Properties
material.density = 7650;              % kg/m³ (7.65 g/cm³)
material.youngs_modulus = 200e9;      % Pa (200 GPa)
material.poissons_ratio = 0.30;       % dimensionless
material.yield_strength = 350e6;      % Pa (350 MPa)
material.tensile_strength = 450e6;    % Pa (450 MPa)
material.hardness = 180;              % HV (Vickers Hardness)

% Electrical Properties
material.electrical_resistivity = 4.5e-7;  % Ω·m (0.45 µΩ·m)
material.relative_permeability_initial = 2000;  % dimensionless (at low H)
material.relative_permeability_max = 6000;      % dimensionless (peak)
material.coercivity = 80;             % A/m (coercive force)
material.saturation_flux_density = 2.01;  % Tesla (T)
material.core_loss_1T_60Hz = 2.5;     % W/kg (watts per kilogram at 1T, 60Hz)

% Thermal Properties
material.thermal_conductivity = 28;   % W/(m·K)
material.specific_heat = 460;         % J/(kg·K)
material.thermal_expansion = 11.5e-6; % 1/K (coefficient of thermal expansion)
material.curie_temperature = 740;     % °C (magnetic transition temperature)

% Lamination Properties
material.lamination_thickness = 0.36; % mm (typical for M19: 0.36 mm or 14 mil)
material.stacking_factor = 0.95;      % 95% (accounts for insulation coating)
material.insulation_coating = 'C5';   % coating type

fprintf('✓ Material properties assigned:\n');
fprintf('  ═══════════════════════════════════════════\n');
fprintf('  MATERIAL: %s\n', material.name);
fprintf('  Grade: %s\n', material.grade);
fprintf('  Type: %s\n', material.type);
fprintf('  ═══════════════════════════════════════════\n\n');

fprintf('  MECHANICAL PROPERTIES:\n');
fprintf('  ─────────────────────────────────────────\n');
fprintf('  • Density: %.0f kg/m³\n', material.density);
fprintf('  • Young''s Modulus: %.0f GPa\n', material.youngs_modulus/1e9);
fprintf('  • Poisson''s Ratio: %.2f\n', material.poissons_ratio);
fprintf('  • Yield Strength: %.0f MPa\n', material.yield_strength/1e6);
fprintf('  • Tensile Strength: %.0f MPa\n', material.tensile_strength/1e6);
fprintf('  • Hardness: %.0f HV\n', material.hardness);
fprintf('\n');

fprintf('  ELECTRICAL & MAGNETIC PROPERTIES:\n');
fprintf('  ─────────────────────────────────────────\n');
fprintf('  • Electrical Resistivity: %.2f µΩ·m\n', material.electrical_resistivity*1e6);
fprintf('  • Initial Relative Permeability: %.0f\n', material.relative_permeability_initial);
fprintf('  • Maximum Relative Permeability: %.0f\n', material.relative_permeability_max);
fprintf('  • Coercivity: %.0f A/m\n', material.coercivity);
fprintf('  • Saturation Flux Density: %.2f T\n', material.saturation_flux_density);
fprintf('  • Core Loss @ 1T, 60Hz: %.2f W/kg\n', material.core_loss_1T_60Hz);
fprintf('\n');

fprintf('  THERMAL PROPERTIES:\n');
fprintf('  ─────────────────────────────────────────\n');
fprintf('  • Thermal Conductivity: %.0f W/(m·K)\n', material.thermal_conductivity);
fprintf('  • Specific Heat Capacity: %.0f J/(kg·K)\n', material.specific_heat);
fprintf('  • Thermal Expansion Coeff.: %.2f × 10⁻⁶ /K\n', material.thermal_expansion*1e6);
fprintf('  • Curie Temperature: %.0f °C\n', material.curie_temperature);
fprintf('\n');

fprintf('  LAMINATION SPECIFICATIONS:\n');
fprintf('  ─────────────────────────────────────────\n');
fprintf('  • Lamination Thickness: %.2f mm (%.0f mil)\n', ...
    material.lamination_thickness, material.lamination_thickness/0.0254);
fprintf('  • Stacking Factor: %.2f (%.0f%%)\n', ...
    material.stacking_factor, material.stacking_factor*100);
fprintf('  • Insulation Coating: %s\n', material.insulation_coating);
fprintf('  ═══════════════════════════════════════════\n\n');

% Visualize with material color coding (steel gray color)
subplot(1,2,2);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.5 0.55 0.6], 'EdgeColor','none', ...
      'FaceAlpha',0.9);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Step 3: Material Applied (Silicon Steel)');
camlight headlight; lighting gouraud;
view(45,30);

%% ========================================================================
%%  STEP 4: BOUNDARY CONDITIONS & CONSTRAINTS
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 4: BOUNDARY CONDITIONS & CONSTRAINTS\n');
fprintf('========================================\n');

% Define boundary conditions
% Find bottom nodes (fixed constraint)
z_min = min(V_rot(:,3));
z_max = max(V_rot(:,3));
tolerance = (z_max - z_min) * 0.05; % 5% tolerance

fixed_nodes = find(V_rot(:,3) < (z_min + tolerance));
fprintf('✓ Fixed constraint applied:\n');
fprintf('  - Location: Bottom surface (Z < %.2f mm)\n', z_min + tolerance);
fprintf('  - Number of constrained nodes: %d\n', length(fixed_nodes));
fprintf('  - DOF constrained: UX = 0, UY = 0, UZ = 0\n');
fprintf('  - Constraint type: Fully fixed (encastre)\n');

% Define mechanical loading
load_nodes = find(V_rot(:,3) > (z_max - tolerance));
load_magnitude = 1000; % N (total force)
load_per_node = load_magnitude / length(load_nodes); % distributed

fprintf('\n✓ Mechanical load applied:\n');
fprintf('  - Location: Top surface (Z > %.2f mm)\n', z_max - tolerance);
fprintf('  - Number of loaded nodes: %d\n', length(load_nodes));
fprintf('  - Total force: %.0f N (downward, -Z direction)\n', load_magnitude);
fprintf('  - Force per node: %.3f N\n', load_per_node);
fprintf('  - Load type: Distributed surface force\n');

% Define electromagnetic boundary conditions (for FEA analysis)
fprintf('\n✓ Electromagnetic boundary conditions:\n');
fprintf('  - Magnetic flux direction: Assumed axial (Z-direction)\n');
fprintf('  - Operating frequency: 60 Hz (typical for power applications)\n');
fprintf('  - Magnetic flux density: 1.5 T (design point)\n');
fprintf('  - Lamination orientation: Parallel to XY plane\n');
fprintf('  - Eddy current analysis: Enabled (laminated structure)\n');

% Visualize boundary conditions
figure('Color','w','Position',[100 100 1200 600]);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.85 0.85 0.9], 'EdgeColor','none', 'FaceAlpha',0.4);
hold on;

% Plot fixed nodes (red)
plot3(V_rot(fixed_nodes,1), V_rot(fixed_nodes,2), V_rot(fixed_nodes,3), ...
      'ro', 'MarkerSize',5, 'MarkerFaceColor','r', 'LineWidth',1.5);

% Plot loaded nodes (blue arrows)
arrow_scale = (z_max - z_min) * 0.15;
quiver3(V_rot(load_nodes,1), V_rot(load_nodes,2), V_rot(load_nodes,3), ...
        zeros(length(load_nodes),1), zeros(length(load_nodes),1), ...
        -ones(length(load_nodes),1)*arrow_scale, 'b', 'LineWidth',2, ...
        'MaxHeadSize',1.5, 'AutoScale','off');

axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Step 4: Boundary Conditions (Red=Fixed, Blue Arrows=Applied Load)');
legend('Silicon Steel Geometry','Fixed Constraint (Bottom)',...
       'Applied Load (Top)','Location','best');
camlight headlight; lighting gouraud;
view(45,30);
hold off;

%% ========================================================================
%%  STEP 5: MESH GENERATION
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 5: MESH GENERATION\n');
fprintf('========================================\n');

% Generate mesh using existing triangulation
fprintf('Generating surface mesh for laminated core...\n');

TR_mesh = triangulation(F, V_rot);

% Calculate mesh quality metrics
edges_list = edges(TR_mesh);
edge_lengths = sqrt(sum((V_rot(edges_list(:,1),:) - V_rot(edges_list(:,2),:)).^2, 2));
mean_edge_length = mean(edge_lengths);
min_edge_length = min(edge_lengths);
max_edge_length = max(edge_lengths);
std_edge_length = std(edge_lengths);

fprintf('✓ Mesh generated successfully\n');
fprintf('  ─────────────────────────────────────────\n');
fprintf('  MESH STATISTICS:\n');
fprintf('  • Mesh type: Surface Triangular Mesh\n');
fprintf('  • Number of nodes: %d\n', size(V_rot,1));
fprintf('  • Number of elements: %d\n', size(F,1));
fprintf('  • Number of edges: %d\n', size(edges_list,1));
fprintf('  ─────────────────────────────────────────\n');
fprintf('  EDGE LENGTH STATISTICS:\n');
fprintf('  • Mean edge length: %.3f mm\n', mean_edge_length);
fprintf('  • Min edge length: %.3f mm\n', min_edge_length);
fprintf('  • Max edge length: %.3f mm\n', max_edge_length);
fprintf('  • Std deviation: %.3f mm\n', std_edge_length);
fprintf('  • Uniformity ratio: %.3f (min/max)\n', min_edge_length/max_edge_length);

% Calculate element quality (aspect ratio for triangles)
element_quality = zeros(size(F,1),1);
element_area = zeros(size(F,1),1);

for i = 1:size(F,1)
    % Get triangle vertices
    v1 = V_rot(F(i,1),:);
    v2 = V_rot(F(i,2),:);
    v3 = V_rot(F(i,3),:);
    
    % Calculate side lengths
    a = norm(v2-v1);
    b = norm(v3-v2);
    c = norm(v1-v3);
    
    % Semi-perimeter
    s = (a+b+c)/2;
    
    % Area using Heron's formula
    area = sqrt(max(0, s*(s-a)*(s-b)*(s-c))); % max to avoid numerical issues
    element_area(i) = area;
    
    % Aspect ratio (quality metric: 1.0 = perfect equilateral triangle)
    if (a^2 + b^2 + c^2) > 0
        element_quality(i) = 4*sqrt(3)*area / (a^2 + b^2 + c^2);
    else
        element_quality(i) = 0;
    end
end

mean_quality = mean(element_quality);
min_quality = min(element_quality);
max_quality = max(element_quality);
total_area = sum(element_area);

fprintf('  ─────────────────────────────────────────\n');
fprintf('  ELEMENT QUALITY METRICS:\n');
fprintf('  • Mean element quality: %.4f\n', mean_quality);
fprintf('  • Min element quality: %.4f\n', min_quality);
fprintf('  • Max element quality: %.4f\n', max_quality);
fprintf('  • Quality > 0.7 (excellent): %d elements (%.1f%%)\n', ...
    sum(element_quality > 0.7), 100*sum(element_quality > 0.7)/length(element_quality));
fprintf('  • Quality > 0.5 (good): %d elements (%.1f%%)\n', ...
    sum(element_quality > 0.5), 100*sum(element_quality > 0.5)/length(element_quality));
fprintf('  • Quality < 0.3 (poor): %d elements (%.1f%%)\n', ...
    sum(element_quality < 0.3), 100*sum(element_quality < 0.3)/length(element_quality));
fprintf('  ─────────────────────────────────────────\n');
fprintf('  GEOMETRIC PROPERTIES:\n');
fprintf('  • Total surface area: %.2f mm²\n', total_area);
fprintf('  • Average element area: %.4f mm²\n', mean(element_area));
fprintf('  ─────────────────────────────────────────\n');

% Calculate approximate volume (for laminated core)
% Assuming uniform lamination thickness
fprintf('  LAMINATION PROPERTIES:\n');
fprintf('  • Lamination thickness: %.2f mm\n', material.lamination_thickness);
fprintf('  • Effective volume (single layer): %.2f mm³\n', ...
    total_area * material.lamination_thickness);
fprintf('  • Effective volume (w/ stacking factor): %.2f mm³\n', ...
    total_area * material.lamination_thickness * material.stacking_factor);
fprintf('  • Mass per layer: %.4f kg\n', ...
    total_area * material.lamination_thickness * material.stacking_factor * ...
    material.density * 1e-9); % convert mm³ to m³
fprintf('  ─────────────────────────────────────────\n');

%% ========================================================================
%%  STEP 6: 3D MESH VISUALIZATION
%% ========================================================================
fprintf('\n========================================\n');
fprintf('STEP 6: MESH VISUALIZATION\n');
fprintf('========================================\n');

% Create comprehensive mesh visualization
figure('Color','w','Position',[50 50 1600 900]);

% Subplot 1: Mesh with edges visible
subplot(2,3,1);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.6 0.65 0.7], 'EdgeColor','k', 'LineWidth',0.5);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Mesh with Edges - Silicon Steel');
view(45,30);
camlight; lighting gouraud;

% Subplot 2: Mesh colored by element quality
subplot(2,3,2);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceVertexCData',element_quality, ...
      'FaceColor','flat', 'EdgeColor','none');
colormap(jet);
cb = colorbar;
cb.Label.String = 'Element Quality';
caxis([0 1]);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Element Quality Distribution');
camlight headlight; lighting gouraud;
view(45,30);

% Subplot 3: Front view with mesh
subplot(2,3,3);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.55 0.6 0.65], 'EdgeColor',[0.3 0.3 0.35], 'LineWidth',0.4);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Front View - Laminated Core');
view(0,0);
camlight; lighting gouraud;

% Subplot 4: Side view
subplot(2,3,4);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.55 0.6 0.65], 'EdgeColor',[0.3 0.3 0.35], 'LineWidth',0.4);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Side View - Lamination Stack');
view(90,0);
camlight; lighting gouraud;

% Subplot 5: Top view
subplot(2,3,5);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.55 0.6 0.65], 'EdgeColor',[0.3 0.3 0.35], 'LineWidth',0.4);
axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Top View - Cross Section');
view(0,90);
camlight; lighting gouraud;

% Subplot 6: Isometric with boundary conditions
subplot(2,3,6);
patch('Faces',F, 'Vertices',V_rot, ...
      'FaceColor',[0.75 0.75 0.8], 'EdgeColor',[0.4 0.4 0.45], ...
      'LineWidth',0.3, 'FaceAlpha',0.7);
hold on;

% Fixed nodes
plot3(V_rot(fixed_nodes,1), V_rot(fixed_nodes,2), V_rot(fixed_nodes,3), ...
      'ro', 'MarkerSize',4, 'MarkerFaceColor','r');

% Load arrows
quiver3(V_rot(load_nodes,1), V_rot(load_nodes,2), V_rot(load_nodes,3), ...
        zeros(length(load_nodes),1), zeros(length(load_nodes),1), ...
        -ones(length(load_nodes),1)*arrow_scale, 'b', 'LineWidth',1.5, ...
        'AutoScale','off');

axis equal; grid on;
xlabel('X [mm]'); ylabel('Y [mm]'); zlabel('Z [mm]');
title('Complete FEA Setup - Silicon Steel');
legend('Mesh','Fixed Constraint','Applied Load','Location','best');
view(45,30);
camlight; lighting gouraud;
hold off;

fprintf('✓ All visualizations completed\n');
fprintf('  • 6 different views generated\n');
fprintf('  • Mesh quality visualization included\n');
fprintf('  • Boundary conditions displayed\n');

%% ========================================================================
%%  STEP 7: ANALYSIS SUMMARY & RECOMMENDATIONS
%% ========================================================================
fprintf('\n========================================\n');
fprintf('FEA PREPROCESSING COMPLETE\n');
fprintf('========================================\n');
fprintf('Model is ready for FEA solver\n\n');

fprintf('MODEL SUMMARY:\n');
fprintf('├─ Total nodes: %d\n', size(V_rot,1));
fprintf('├─ Total elements: %d\n', size(F,1));
fprintf('├─ Material: %s\n', material.name);
fprintf('├─ Constraints: %d nodes fixed\n', length(fixed_nodes));
fprintf('├─ Loading: %.0f N on %d nodes\n', load_magnitude, length(load_nodes));
fprintf('├─ Mesh quality: %.3f (mean)\n', mean_quality);
fprintf('└─ Surface area: %.2f mm²\n\n', total_area);

fprintf('RECOMMENDED ANALYSIS TYPES:\n');
fprintf('├─ Structural: Static stress analysis\n');
fprintf('├─ Electromagnetic: AC magnetic field analysis\n');
fprintf('├─ Thermal: Eddy current loss heating\n');
fprintf('├─ Modal: Natural frequency analysis\n');
fprintf('└─ Coupled: Magneto-mechanical coupling\n\n');

fprintf('ELECTROMAGNETIC CONSIDERATIONS:\n');
fprintf('├─ Core loss at 1.5T, 60Hz: ~%.2f W/kg\n', ...
    material.core_loss_1T_60Hz * 1.5^2);
fprintf('├─ Lamination reduces eddy currents\n');
fprintf('├─ Stacking factor: %.0f%%\n', material.stacking_factor*100);
fprintf('└─ Consider B-H curve for nonlinear analysis\n\n');

fprintf('========================================\n');
fprintf('Analysis ready for FEM solver!\n');
fprintf('========================================\n');
