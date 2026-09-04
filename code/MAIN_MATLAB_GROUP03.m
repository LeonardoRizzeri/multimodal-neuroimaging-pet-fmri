clc
clear all
close all

% Set paths
code_path = pwd;
pet_input_path = fullfile(code_path, '..', 'data', 'pet');
func_input_path = fullfile(code_path, '..', 'data', 'func');
utils_path=fullfile(code_path,'..','data/utils');

pet_processed_path = fullfile(code_path, '..', 'data_processed', 'pet');
func_processed_path = fullfile(code_path, '..', 'data_processed', 'func');

%mkdir(func_processed_path);

figures_path= fullfile(code_path,'..','/figures');
mkdir(figures_path);



%% Task 2.1
% Load PET data in 4D (x, y, z, time)
PET_moco = niftiread(fullfile(pet_processed_path,'sub-s014_ses-open_task-rest_pet_moco.nii.gz')); 
info_PET = niftiinfo(fullfile(pet_input_path,'sub-s014_ses-open_task-rest_pet.nii.gz')); % PET info
json_text= fileread(fullfile(pet_input_path, "sub-s014_ses-open_task-rest_pet.json"));
json_PET = jsondecode(json_text);

[nR_PET, nC_PET, nS_PET, nVol_PET] = size(PET_moco);
disp("number of volumes: "+num2str(nVol_PET))

% Temporal grid defined in the JSON file (FrameReferenceTime)
frame_duration=json_PET.FrameDuration;
frame_duration_min=frame_duration/60;
frame_times=json_PET.FrameTimesStart;
frame_times_min=frame_times/60;

tot_acquisition_time=sum(frame_duration)/60;
disp("Total acquisition time: "+num2str(tot_acquisition_time)+'min');

Voxel_size=info_PET.PixelDimensions;
disp("voxel size: "+ num2str(Voxel_size(1:3))+'mm');


%% Task 2.5 
% Compute TAC
% Load GM T1w_2_PETspace masks
GM_mask = niftiread(fullfile(pet_processed_path,'GM_mask_2_PETspace.nii.gz'));
GM_mask = double(GM_mask);

% Load NIfTI of atlas
atlas = niftiread(fullfile(pet_input_path,'Schaefer_100Parcels_7Networks_Cereb_2_PET.nii.gz'));
atlas = double(atlas);

% Read ROI labels from Excel file
labels_table = readtable(fullfile(utils_path,'Schaefer_100Parcels_7Networks_Cereb.csv'));
roi_labels = labels_table{:,2};
roi_id = labels_table{:,1};
network_labels=labels_table{:,3}(1:100);


% Verify that the first three dimensions of the three images are the same,
% otherwise they are not in the same space!
[nR_GM_mask, nC_GM_mask, nS_GM_mask] = size(GM_mask);
[nR_atlas, nC_atlas, nS_atlas] = size(atlas);
[nR_PET, nC_PET, nS_PET, nVol_PET] = size(PET_moco);

if (nR_GM_mask==nR_atlas) && (nR_GM_mask==nR_PET) && (nR_atlas==nR_PET) ... % Check if atlas and mask dimensions match
        && (nC_GM_mask==nC_atlas) && (nC_GM_mask==nC_PET) && (nC_atlas==nC_PET) ... 
        && (nS_GM_mask==nS_atlas) && (nS_GM_mask==nS_PET) && (nS_atlas==nS_PET)
   
    % -------------------- ATLAS MASKING --------------------

    % atlas masked for the GM mask
    atlas_GM_masked = atlas.*(GM_mask>0);
    %implay(atlas_GM_masked)

    % Number of regions (ROIs) in the atlas
    n_ROI = length(roi_id);

    % -------------------- TAC EXTRACTION --------------------

    % Pre-allocate a matrix with dimensions n_ROI x n_PET_volumes
    PET_TAC = zeros(n_ROI,nVol_PET);
     
    % For loop for each of the n_ROI
    for ii = 1:n_ROI

        % Identify the label of the current ROI
        roi = roi_id(ii);
              
        % Extract the voxels in the atlas masked for the GM mask equal to
        % the label of the current ROI
        roi_mask = atlas_GM_masked == roi; 

        % CHECK 1: Exclude ROIs with zero voxels after masking
        if nnz(roi_mask) == 0
            PET_TAC(ii, :) = NaN; % Assign NaN to the entire row to exclude it
            continue; 
        end
            
        % For loop for each of the PET volumes (4th dimension of the PET
        % file), to extract the mean value for each volume
        for tt = 1:nVol_PET
            vol = PET_moco(:,:,:,tt); % Current volume
            roi_voxels = vol(roi_mask); % Vectorized voxel values belonging to the current ROI
            
            % CHECK 2: Handle non-physiological values (<= 0)
            roi_voxels(roi_voxels <= 0) = NaN;

            PET_TAC(ii,tt) = mean(roi_voxels,'omitnan'); % Mean value of all extracted voxels for that ROI and volume
        end

    end


    
    % -------------------- PLOT 7 NETWORKS + CEREBELLUM --------------------
    idx_ref = 101:118; % Cerebellar ROI indices (AAL3)
    TAC_reference = mean(PET_TAC(idx_ref, :), 1, 'omitnan');
    
    % Find unique networks (should be 7)
    unique_networks = unique(network_labels);
    n_networks = length(unique_networks);
    
    % Calculate mean TAC for each network
    network_TACs = zeros(n_networks, nVol_PET);
    for n = 1:n_networks
        % Find all ROIs belonging to this specific network
        idx_net = find(strcmp(network_labels, unique_networks{n}));
        % Spatial mean of the network ROIs
        network_TACs(n, :) = mean(PET_TAC(idx_net, :), 1, 'omitnan');
    end
    
    % Figure 
    figure('Color', 'w', 'Name', '7 Networks + Cerebellum TACs');
    hold on;
    
    % Generate distinct colors for the 7 networks
    colors = lines(n_networks); 
    
    % Plot curves for the 7 networks
    lines_array = gobjects(n_networks + 1, 1);% Array to store handles for the legend
    for n = 1:n_networks
        lines_array(n) = plot(frame_times_min, network_TACs(n, :), 'Color', colors(n,:), 'LineWidth', 2.5, 'DisplayName', unique_networks{n});
    end
    
    % Plot cerebellum (Reference) in dashed black to make it stand out
    lines_array(end) = plot(frame_times_min, TAC_reference, 'k--', 'LineWidth', 3, 'DisplayName', 'Cerebellum');
    
    xlim([0 frame_times_min(end)])
    xlabel('Time [min]', 'FontSize', 14, 'FontWeight', 'bold')
    ylabel('Concentration [Bq/mL]', 'FontSize', 14, 'FontWeight', 'bold')
    title('PET TACs across regions', 'FontSize', 16)
    legend(lines_array, 'Location', 'eastoutside', 'FontSize', 12)
    grid on;
    set(gca, 'FontSize', 12);
    
    
else
    disp('The three images are not in the same space! Check the registrations')
end

exportgraphics(gca, fullfile(figures_path,'Figure2_TACs.png'))

%% Plot parameters to select an appropriate time window
 
% load motion parameters
motion_params = load(fullfile(pet_processed_path,'sub-s014_ses-open_task-rest_pet_moco.nii.gz.par'));

figure('Color', 'w', 'Name', 'MCFLIRT Estimated Realignment Parameters');

% Subplot 1: Rotations
% Conversion from rad to deg
rotations_deg = rad2deg(motion_params(:, 1:3));
subplot(2,1,1);
plot(frame_times_min, rotations_deg, '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
title('Estimated Rotations (PET Dynamics)','FontSize',14);
ylabel('Deg','FontSize',14);
xlabel('Time (min)','FontSize',14), xlim([0 frame_times_min(end)]), xticks(frame_times_min), xtickangle(90)
legend('x (pitch)', 'y (roll)', 'z (yaw)', 'Location', 'best');
grid on;

% Subplot 2: Translations
subplot(2,1,2);
plot(frame_times_min, motion_params(:, 4:6), '-o', 'LineWidth', 1.5, 'MarkerSize', 4);
title('Estimated Translations (PET Dynamics)','FontSize',14);
ylabel('mm','FontSize',14);
xlabel('Time (min)','FontSize',14), xlim([0 frame_times_min(end)]), xticks(frame_times_min), xtickangle(90)
legend('x', 'y', 'z', 'Location', 'best');
grid on;

sgtitle('Head Motion Parameters over Scan Duration');
exportgraphics(gcf,fullfile(figures_path,'Motion_parameters_PET.png'))

%% Compute SUVr at the ROI level

% After examining the motion parameters, I have decided to calculate the SUVr map 
% within a [25–35]-minute window, a trade off between subject motion and the 
% tracer reaching steady state.

% 1. Define the time window
time_window_idx = find(frame_times_min >= 25 & frame_times_min <= 35);

% 2. Calculate the average PET signal for each ROI in the selected time window
% We use the already extracted PET_TAC matrix (118 ROIs x 39 frames)
PET_TAC_late = mean(PET_TAC(:, time_window_idx), 2, 'omitnan');

% 3. Calculate the average PET signal for the Cerebellum (Reference) in the time window
% We use the TAC_reference extracted previously
Ref_late = mean(TAC_reference(time_window_idx), 'omitnan');

% 4. Compute SUVr for all ROIs
% Divide the late activity of each ROI by the reference activity
SUVR_all_ROIs = PET_TAC_late / Ref_late;

% 5. Isolate only the 100 Cortical ROIs for the plot (exclude cerebellar ROIs)
idx_cortical = 1:100;
SUVR_Cortical = SUVR_all_ROIs(idx_cortical);
labels_cortical = roi_labels(idx_cortical);

% -------------------- STEM PLOT --------------------
% Plot the SUVR values using a stem plot
figure('Color', 'w', 'Position', [100, 100, 1200, 500])
stem(idx_cortical, SUVR_Cortical, 'filled', 'LineWidth', 1.5, 'MarkerSize', 5, 'Color', [0 0.4470 0.7410])

xlabel('Cortical ROIs', 'FontSize', 12, 'FontWeight', 'bold')
ylabel('SUVr', 'FontSize', 12, 'FontWeight', 'bold')
title('SUVR across 100 Cortical ROIs (Time window: 25-35 min)', 'FontSize', 14)

% X-axis formatting
xlim([0 101])
xticks(1:100)
xticklabels(strrep(strrep(labels_cortical(idx_cortical),'_',' '),'7Networks',''))
xtickangle(90)
grid on
hold on

% Add a reference line for SUVR = 1
yline(1, 'r--', 'SUVr = 1 (Reference Level)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left')

exportgraphics(gca, fullfile(figures_path, 'Figure3_SUVR_stem.png'))

%% Task 3.1
% Describe the data: Number of volumes, TR, Voxel size, Scanner field strength
fmri_data=jsondecode(fileread(fullfile(func_input_path,'sub-s014_ses-open_task-rest_bold.json')));
fMRI=niftiread(fullfile(func_input_path,"sub-s014_ses-open_task-rest_bold_SlTi_moco.nii.gz"));
info = niftiinfo(fullfile(func_input_path,"sub-s014_ses-open_task-rest_bold_SlTi_moco.nii.gz"));

% Get fMRI dimensions
[nR_fMRI, nC_fMRI, nS_fMRI, nVol_fMRI] = size(fMRI);

TR = fmri_data.RepetitionTime;
Field_size = fmri_data.MagneticFieldStrength;

% Voxel dimensions [x y z] in mm
voxel_size = info.PixelDimensions(1:3);

fprintf('Number of volumes: %d\n', nVol_fMRI);
fprintf('TR: %.3f s\n', TR);
fprintf('Voxel size: %.3f x %.3f x %.3f mm\n', ...
        voxel_size(1), voxel_size(2), voxel_size(3));
fprintf('Magnetic field strength: %.1f T\n', Field_size);

fprintf('fMRI dimensions: %s\n', mat2str(size(fMRI)));

%% Task 3.2 
% Use the file 'sub-s014_ses-open_task-rest_bold_SlTi_moco.par' to compute the 
% framewise displacement (FD) metric:
motion_fMRI = load(fullfile(func_input_path,'sub-s014_ses-open_task-rest_bold_SlTi_moco.par'));
% - Mean FD
% - Maximum FD
% - Number of volumes with FD > 0.5 mm
% - Comment on motion (high vs low)
% - Plot motion parameters and FD

% Compute differences between consecutive timepoints
diff_motion = diff(motion_fMRI);

% Separate rotations and translations
rot = diff_motion(:,1:3); % radians
trans = diff_motion(:,4:6); % mm

% Convert rotations to mm (arc length: R * theta)
% Radius of the head (in mm, standard choice)
R = 50;
rot_mm = R * rot;

% Compute FD (sum of absolute values)
FD = sum(abs([rot_mm trans]), 2);

% Add 0 for first volume (no previous frame)
FD = [0; FD];

% Print summary metrics
fprintf('Mean FD: %.4f mm\n', mean(FD));
fprintf('Max FD: %.4f mm\n', max(FD));
fprintf('Percentage of volumes with FD > 0.5 mm: %d\n\n', 100*(sum(FD > 0.5))/nVol_fMRI);

% Visualization 
figure;
subplot(311)
plot(rot_mm, 'LineWidth', 1.5);
hold on;
title('Estimated Rotation','FontSize',14);
ylabel('Degrees','FontSize',12);
xlabel('Volumes','FontSize',12)
grid on;

subplot(312)
plot(trans, 'LineWidth', 1.5);
hold on;
title('Estimated Translations','FontSize',14);
ylabel('mm','FontSize',12);
xlabel('Volumes','FontSize',12)
grid on;

subplot(313)
plot(FD, 'k', 'LineWidth', 1.5);
hold on;
yline(0.5, '--r', '0.5 mm threshold'); % common threshold to mark a volume as motion outlier
title('Framewise Displacement (Power et al 2012)','FontSize',14);
ylabel('mm','FontSize',12);
xlabel('Volumes','FontSize',12)
grid on;


exportgraphics(gcf,fullfile(figures_path,'Figure4_FD.png'))

%% Task 3.3
% Coregister masks to fMRI space: Use the pre-computed transform: 
% 'sub-s014_ses-open_task-rest_bold_SlTi_moco_brain_2_T1.mat' to bring WM, GM, 
% CSF masks into fMRI space. Adapt this transform matrix if needed.

%% Task 3.4 - Voxelwise nuisance regression

fMRI = double(fMRI);

% Load masks already registered to fMRI space
GM_mask_fMRI  = niftiread(fullfile(func_processed_path,'GM_mask_2_fMRIspace.nii.gz'));
WM_mask_fMRI  = niftiread(fullfile(func_processed_path,'WM_mask_2_fMRIspace.nii.gz'));
CSF_mask_fMRI = niftiread(fullfile(func_processed_path,'CSF_mask_2_fMRIspace.nii.gz'));

GM_mask_fMRI  = double(GM_mask_fMRI);
WM_mask_fMRI  = double(WM_mask_fMRI);
CSF_mask_fMRI = double(CSF_mask_fMRI);

% Load atlas in fMRI space
atlas_fMRI = niftiread(fullfile(func_input_path,'Schaefer_100Parcels_7Networks_Cereb_2_fMRI.nii.gz'));
atlas_fMRI = double(atlas_fMRI);


% Reshape fMRI from 4D to 2D: voxels x time
fMRI_2D = reshape(fMRI, [], nVol_fMRI);


%% Background masking

mean_fMRI = mean(fMRI,4);

figure('Color','w','Name','fMRI mean intensity histogram');
histogram(mean_fMRI(:),100);
xlabel('Mean BOLD intensity');
ylabel('Number of voxels');
title('Histogram of mean rs-fMRI signal');

% To be selected after visual inspection of the histogram
% background_thr = [100,120,150,170,300,320,350,370];
% figure
% for i=1:length(background_thr)
%     brain_mask = mean_fMRI > background_thr(i);
%     subplot(2,4,i)
%     imagesc(brain_mask(:,:,round(size(brain_mask,3)/2)))
%     axis image
%     colormap gray
%     title(sprintf('Brain mask from threshold =%d', background_thr(i)))
% end
% 370 is the most convincing threshold: removes background creating a small internal hole.

background_thr = 370;
brain_mask = mean_fMRI > background_thr;

% Define voxels for nuisance regression
WM_idx  = WM_mask_fMRI(:)  > 0 & brain_mask(:); 
CSF_idx = CSF_mask_fMRI(:) > 0 & brain_mask(:);

% Regression is performed only on GM voxels inside atlas ROIs
GM_atlas_idx = GM_mask_fMRI(:) > 0 & atlas_fMRI(:) > 0 & brain_mask(:);

% Extract WM and CSF signals
WM_ts  = fMRI_2D(WM_idx, :);     % WM voxels x time
CSF_ts = fMRI_2D(CSF_idx, :);    % CSF voxels x time

% Transpose for PCA: time x voxels
WM_ts_T  = WM_ts';
CSF_ts_T = CSF_ts';

% Remove temporal mean
WM_ts_T  = detrend(WM_ts_T, 'constant');
CSF_ts_T = detrend(CSF_ts_T, 'constant');

% PCA on WM and CSF signals
[~, score_WM, ~, ~, explained_WM] = pca(WM_ts_T);
[~, score_CSF, ~, ~, explained_CSF] = pca(CSF_ts_T);

WM_PCs  = score_WM(:,1:5);
CSF_PCs = score_CSF(:,1:5);

cumvar_WM  = sum(explained_WM(1:5));
cumvar_CSF = sum(explained_CSF(1:5));

disp("Cumulative variance explained by first 5 WM PCs: " + num2str(cumvar_WM) + "%")
disp("Cumulative variance explained by first 5 CSF PCs: " + num2str(cumvar_CSF) + "%")

%% Design matrix

% First derivatives of motion parameters
motion_derivatives = [zeros(1,6); diff_motion];

% Design matrix without intercept
X = [ones(nVol_fMRI,1),motion_fMRI, motion_derivatives, CSF_PCs, WM_PCs];


% Plot design matrix excluding intercept
figure('Color','w','Name','Design matrix');
imagesc(zscore(X(:,2:end)));
colormap gray;
colorbar;
xlabel('Regressors');
ylabel('Time points');
title('Design matrix for nuisance regression');

exportgraphics(gcf, fullfile(figures_path,'Figure5_design_matrix.png'));

% Voxelwise nuisance regression

% Extract GM voxel time series inside atlas ROIs
Y = fMRI_2D(GM_atlas_idx, :)';   % time x voxels

% GLM estimation
beta = X \ Y;

% Residuals = cleaned BOLD signal
Y_clean = Y - X * beta;

% Reconstruct cleaned 2D matrix
fMRI_clean_2D = zeros(size(fMRI_2D));
fMRI_clean_2D(GM_atlas_idx,:) = Y_clean';

% Reshape back to 4D
fMRI_clean = reshape(fMRI_clean_2D, nR_fMRI, nC_fMRI, nS_fMRI, nVol_fMRI);

%% Task 3.5 High-pass temporal filtering

disp('High pass temporal filtering')

fs = 1/TR; % sampling frequency
freq_hp = 1/128; % cut-off freq at 1/128Hz = 0.0078Hz 
[b,a] = butter(3,freq_hp/(fs/2), 'high'); % high pass filter

% Perform high-pass filtering of the cleaned data using filtfilt
Y_filtered = filtfilt(b,a,Y_clean); 

% Reconstruct filtered 2D matrix
fMRI_filtered_2D = zeros(size(fMRI_2D));

fMRI_filtered_2D(GM_atlas_idx, :) = Y_filtered';

% Reshape back to 4D
fMRI_filtered = reshape(fMRI_filtered_2D, nR_fMRI, nC_fMRI, nS_fMRI, nVol_fMRI);


%% Task 3.6 Plot BOLD time series for selected ROIs
disp('Task 3.6: Plotting time series');

% 1. Target ROIs defined in the assignment
target_rois = {'LH_SomMot_6', 'LH_DorsAttn_Post_1', 'RH_DorsAttn_FEF_1', 'RH_SalVentAttn_TempOccPar_1'};

% 2. Initialize Figure 6
figure('Color','w','Name','Figure 6: BOLD Time Series', 'Position', [100, 100, 1200, 800]);

for i = 1:length(target_rois)
    
    % Mask for the current ROI
    roi_row_idx = contains(roi_labels, target_rois{i}); 
    
    % Safety check: verify that the ROI was found
    if sum(roi_row_idx) == 0
        warning('ROI "%s" not found. Check the table.', target_rois{i});
        continue; 
    end
    
    % Extract ID from column 1 (ROILabel)
    roi_id_raw = labels_table{roi_row_idx, 1}; 
    
    % Ensure ID is a double scalar to avoid dimension errors
    if iscell(roi_id_raw)
        current_roi_id = str2double(roi_id_raw{1});
    elseif isstring(roi_id_raw) || ischar(roi_id_raw)
        current_roi_id = str2double(roi_id_raw);
    else
        current_roi_id = double(roi_id_raw(1));
    end
    
    % Find voxels belonging to this ROI that are ALSO in the GM mask
    current_roi_idx = (atlas_fMRI(:) == current_roi_id) & GM_atlas_idx;
    
    % Compute the mean BOLD signal across voxels for all 3 processing stages
    ts_original = mean(fMRI_2D(current_roi_idx, :), 1);
    ts_clean    = mean(fMRI_clean_2D(current_roi_idx, :), 1);
    ts_filtered = mean(fMRI_filtered_2D(current_roi_idx, :), 1);
    
    % Z-score for visualization on the same scale
    ts_orig_z = zscore(ts_original);
    ts_clean_z = zscore(ts_clean);
    ts_filt_z = zscore(ts_filtered);
    
    % Plotting
    subplot(length(target_rois), 1, i);
    plot(1:nVol_fMRI, ts_orig_z, 'r', 'LineWidth', 1); hold on;
    plot(1:nVol_fMRI, ts_clean_z, 'g', 'LineWidth', 1);
    plot(1:nVol_fMRI, ts_filt_z, 'b', 'LineWidth', 1.5);
    
    title(strrep(target_rois{i}, '_', ' '));
    xlabel('Volumes');
    ylabel('Standardized BOLD');
    grid on;
    
    if i == 1
        legend('After MoCo', 'After Nuisance Regression', 'After Filtering', 'Location', 'best');
    end
end

exportgraphics(gcf, fullfile(figures_path, 'Figure6_BOLD_timeseries.png'));

%% Task 3.7 : Compute static functional connectivity (Lab 8)

% Pre-allocate matrix:
% rows = time points
% columns = ROIs
ROI_data_filt = zeros(nVol_fMRI, length(idx_cortical));

for rr = 1:length(idx_cortical)

    % Current ROI ID from the labels table
    current_roi_id = roi_id(idx_cortical(rr));

    % Extract voxels belonging to the current ROI, within GM and atlas mask
    curr_roi_idx = (atlas_fMRI(:) == current_roi_id) & GM_atlas_idx;

    % Safety check: if no voxel survives the masking, assign NaN
    if nnz(curr_roi_idx) == 0
        warning('ROI %d has zero voxels after GM/background masking.', current_roi_id);
        ROI_data_filt(:,rr) = NaN;
        continue
    end

    % Extract voxel time series from filtered fMRI data
    % fMRI_filtered_2D has dimensions: voxels x time
    data2D_filt = fMRI_filtered_2D(curr_roi_idx, :);

    % Average across voxels and store the ROI mean time series
    ROI_data_filt(:,rr) = mean(data2D_filt, 1, 'omitnan')';

end

% Remove ROIs with NaN time series, if present
valid_roi = all(~isnan(ROI_data_filt), 1);
ROI_data_filt = ROI_data_filt(:, valid_roi);

roi_labels_cortical = roi_labels(idx_cortical);
roi_labels_cortical = roi_labels_cortical(valid_roi);

roi_id_cortical = roi_id(idx_cortical);
roi_id_cortical = roi_id_cortical(valid_roi);

nROI = size(ROI_data_filt, 2);

fprintf('Number of valid cortical ROIs used for FC: %d/100\n', nROI);


% -------------------- Functional Connectivity --------------------

% Compute Pearson correlation matrix between ROI time series
% corr expects observations in rows and variables in columns:
% rows = time points, columns = ROIs
%[FC_matrix, pval_matrix] = corr(ROI_data_filt, 'Type', 'Pearson', 'Rows', 'pairwise');
[FC_matrix, pval_matrix] = corr(ROI_data_filt);

% Fisher z-transformation
FC_z = atanh(FC_matrix);

% Remove diagonal, because self-correlations are not informative
FC_matrix(1:size(FC_matrix,1)+1:end) = 0;
FC_z(1:size(FC_z,1)+1:end) = 0;
pval_matrix(1:size(pval_matrix,1)+1:end) = 1;

% FDR Masking
idx_upper_tri = find(triu(ones(nROI),1));  %find the indices of the elements in the upper triangular matrix
pvals_vec = pval_matrix(idx_upper_tri); %extract the pvalues in those indices
q_thresh = 0.05;            % you can use 0.01

addpath(utils_path)
sig_vec = fdr_bh(pvals_vec,q_thresh);

% Reconstruct full matrix
sig_mask = false(nROI);
sig_mask(idx_upper_tri) =sig_vec; 
% Make symmetric using logical OR
sig_mask = sig_mask | sig_mask';

% Apply mask to FC matrix and z-Fisher transformed matrix
FC_matrix_thresh = FC_matrix .*sig_mask;
FC_z_thresh = FC_z .* sig_mask; 

% -------------------- Visualization before FDR --------------------
% Figure 7 - Static FC matrix after z-Fisher and FDR masking
figure('Name','Figure 7: Static Functional Connectivity');

% -------------------- Matrix 1: z-Fisher transformed FC --------------------
subplot(1,2,1)
imagesc(FC_z)
axis square
colorbar
title('Static FC matrix after z-Fisher transformation', 'FontSize', 12)

xlabel('Cortical ROIs')
ylabel('Cortical ROIs')

idx_ticks = 1:10:nROI;
xticks(idx_ticks)
yticks(idx_ticks)
xtickangle(90)

xticklabels(strrep(strrep(roi_labels(idx_ticks),'_',' '),'7Networks',''))
yticklabels(strrep(strrep(roi_labels(idx_ticks),'_',' '),'7Networks',''))

% Optional: set symmetric color scale for easier interpretation
max_abs_z = max(abs(FC_z(:)));
clim([-max_abs_z max_abs_z])


% -------------------- Matrix 2: z-Fisher FC after FDR masking --------------------
subplot(1,2,2)
imagesc(FC_z_thresh)
axis square
colorbar
title('FC matrix after masking non-significant connections', 'FontSize', 12)

xlabel('Cortical ROIs')
ylabel('Cortical ROIs')

xticks(idx_ticks)
yticks(idx_ticks)
xtickangle(90)

xticklabels(strrep(strrep(roi_labels_cortical(idx_ticks),'_',' '),'7Networks',''))
yticklabels(strrep(strrep(roi_labels_cortical(idx_ticks),'_',' '),'7Networks',''))

% Use the same color scale as the first matrix
clim([-max_abs_z max_abs_z])

sgtitle('Figure 7 - Static Functional Connectivity', 'FontSize', 14)

exportgraphics(gcf, fullfile(figures_path, 'Figure7_static_FC_zFisher_FDR.png'));


%% Task 3.8 - Graph metrics: Degree and Strength

disp('Task 3.8: Graph metrics from FDR-corrected FC matrix');

FC_matrix_thresh(1:size(FC_matrix_thresh,1)+1:end) = 0;

adj_binary = FC_matrix_thresh ~= 0;

degree = sum(adj_binary, 2);

strength = sum(abs(FC_matrix_thresh), 2);

% Sort ROIs by degree
[degree_sorted, idx_degree_sorted] = sort(degree, 'descend');

% Sort ROIs by strength
[strength_sorted, idx_strength_sorted] = sort(strength, 'descend');

% Number of top ROIs to display
n_top = 5;

disp('Top ROIs by degree:')
top_degree_table = table( ...
    roi_id_cortical(idx_degree_sorted(1:n_top)), ...
    roi_labels_cortical(idx_degree_sorted(1:n_top)), ...
    degree_sorted(1:n_top), ...
    'VariableNames', {'ROI_ID','ROI_Label','Degree'} ...
);
disp(top_degree_table)

disp('Top ROIs by strength:')
top_strength_table = table( ...
    roi_id_cortical(idx_strength_sorted(1:n_top)), ...
    roi_labels_cortical(idx_strength_sorted(1:n_top)), ...
    strength_sorted(1:n_top), ...
    'VariableNames', {'ROI_ID','ROI_Label','Strength'} ...
);
disp(top_strength_table)



figure('Name','Figure 8: Degree and Strength')

subplot(2,1,1)
bar(degree, 'FaceColor', [0 0.4470 0.7410])
xlabel('Cortical ROI')
ylabel('Degree')
title('Node Degree from FDR-corrected FC matrix','FontSize',12)
grid on

xticks(1:nROI)
xticklabels(strrep(strrep(roi_labels_cortical,'_',' '),'7Networks',''))
xtickangle(90)
set(gca,'FontSize',7)


subplot(2,1,2)
bar(strength, 'FaceColor', [0.8500 0.3250 0.0980])
xlabel('Cortical ROI')
ylabel('Strength')
title('Node Strength from FDR-corrected FC matrix','FontSize',12)
grid on

xticks(1:nROI)
xticklabels(strrep(strrep(roi_labels_cortical,'_',' '),'7Networks',''))
xtickangle(90)
set(gca,'FontSize',7)

sgtitle('Figure 8 - Graph metrics from FDR-corrected Functional Connectivity', ...
        'FontSize',14)

exportgraphics(gcf, fullfile(figures_path, 'Figure8_degree_strength.png'));

%% task 3.9
addpath(genpath(fullfile(utils_path,'BrainSpace-master')))

gm=GradientMaps('kernel','gaussian','approach','le');
gm=gm.fit(FC_matrix);

% Plot by ROI
figure('Color', 'w', 'Name', 'Figure 9: Cortical Functional Gradients', 'Position', [100, 100, 800, 600])

gscatter(gm.gradients{1}(:,1), gm.gradients{1}(:,2), network_labels, lines(n_networks), '.', 25) 
xlabel('Gradient 1', 'FontSize', 14, 'FontWeight', 'bold')
ylabel('Gradient 2', 'FontSize', 14, 'FontWeight', 'bold')
title('Functional Gradients Space (G1 vs G2)', 'FontSize', 16)
grid on
legend('Location', 'bestoutside', 'FontSize', 11)


%gradient_in_euclidean(gm.gradients{1}(:,1:2));

exportgraphics(gcf, fullfile(figures_path, 'Figure9_Cortical_Functional_Gradients.png'));

%% Task 4 - PET-rsFMRI Multimodal Integration

disp('Task 4: PET-rsFMRI multimodal integration');

% Cortical SUVR from PET
SUVR = SUVR_Cortical(:);

% Graph metrics from rs-fMRI
degree = degree(:);
strength = strength(:);

% First functional gradient from Task 3.9
grad1 = gm.gradients{1}(:,1);
grad1 = grad1(:);

% Keep only valid values
idx_valid = isfinite(SUVR) & isfinite(degree) & isfinite(strength) & isfinite(grad1);

SUVR = SUVR(idx_valid);
degree = degree(idx_valid);
strength = strength(idx_valid);
grad1 = grad1(idx_valid);

% Spearman correlations
[rho_deg, p_deg] = corr(degree, SUVR, 'Type', 'Spearman', 'Rows', 'complete');
[rho_str, p_str] = corr(strength, SUVR, 'Type', 'Spearman', 'Rows', 'complete');
[rho_grad, p_grad] = corr(grad1, SUVR, 'Type', 'Spearman', 'Rows', 'complete');

fprintf('\nSUVR vs Degree:   rho = %.3f, p = %.4f\n', rho_deg, p_deg);
fprintf('SUVR vs Strength: rho = %.3f, p = %.4f\n', rho_str, p_str);
fprintf('SUVR vs Gradient1: rho = %.3f, p = %.4f\n', rho_grad, p_grad);


%% Figure 10 - PET-rsFMRI integration

figure('Name','Figure 10: PET-rsFMRI integration')

% -------------------- SUVR vs Degree --------------------
subplot(1,3,1)

scatter(degree, SUVR, 60, 'filled')
hold on

pfit = polyfit(degree, SUVR, 1);
xfit = linspace(min(degree), max(degree), 100);
plot(xfit, polyval(pfit, xfit), 'r-', 'LineWidth', 1.5)

xlabel('Degree')
ylabel('SUVR')
title(sprintf('SUVR vs Degree\n\\rho = %.2f, p = %.3f', rho_deg, p_deg))
grid on


% -------------------- SUVR vs Strength --------------------
subplot(1,3,2)

scatter(strength, SUVR, 60, 'filled')
hold on

pfit = polyfit(strength, SUVR, 1);
xfit = linspace(min(strength), max(strength), 100);
plot(xfit, polyval(pfit, xfit), 'r-', 'LineWidth', 1.5)

xlabel('Strength')
ylabel('SUVR')
title(sprintf('SUVR vs Strength\n\\rho = %.2f, p = %.3f', rho_str, p_str))
grid on


% -------------------- SUVR vs Gradient 1 --------------------
subplot(1,3,3)

scatter(grad1, SUVR, 60, 'filled')
hold on

pfit = polyfit(grad1, SUVR, 1);
xfit = linspace(min(grad1), max(grad1), 100);
plot(xfit, polyval(pfit, xfit), 'r-', 'LineWidth', 1.5)

xlabel('Gradient 1')
ylabel('SUVR')
title(sprintf('SUVR vs Gradient 1\n\\rho = %.2f, p = %.3f', rho_grad, p_grad))
grid on


sgtitle('Figure 10 - Relationship between glucose metabolism and functional organization', ...
        'FontSize', 14)

exportgraphics(gcf, fullfile(figures_path, 'Figure10_PET_rsFMRI_integration.png'));


