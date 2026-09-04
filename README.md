# Multimodal Neuroimaging Analysis: FDG-PET and rs-fMRI

This repository contains a multimodal neuroimaging pipeline for integrating structural MRI, dynamic FDG-PET and resting-state fMRI data. The project was developed for an Imaging for Neuroscience workflow and focuses on cortical glucose metabolism, functional connectivity, graph metrics and functional gradients.

The analysis combines T1-weighted anatomical segmentation, PET motion correction and SUVR estimation, rs-fMRI nuisance regression and temporal filtering, static functional connectivity, BrainSpace gradient mapping and PET-fMRI multimodal association analyses.

## Project Overview

The pipeline is organized around one subject-level multimodal dataset including:

- T1-weighted anatomical MRI.
- Dynamic FDG-PET acquired during rest.
- Resting-state fMRI.
- Schaefer 100 cortical parcels with cerebellar reference regions.

The main scientific goal is to compare regional FDG uptake with functional network organization derived from rs-fMRI. In particular, the project estimates whether cortical glucose metabolism is associated with node-level connectivity measures and the principal functional gradient.

## Analysis Workflow

### 1. Structural MRI Processing

The T1-weighted image is processed with FSL tools to obtain tissue probability maps and binary masks for:

- Cerebrospinal fluid.
- Gray matter.
- White matter.

These masks are later transformed into PET and fMRI space for ROI extraction and nuisance regression.

### 2. FDG-PET Processing

The PET workflow includes:

- Motion correction of the dynamic PET series with FSL `mcflirt`.
- Extraction of a reference PET volume.
- PET-to-T1w registration and inverse T1w-to-PET transformation.
- Registration of anatomical tissue masks into PET space.
- Time-activity curve extraction across Schaefer parcels and cerebellar regions.
- Visual inspection of motion parameters.
- SUVR computation using a late uptake window of 25-35 minutes and cerebellar reference signal.

### 3. Resting-State fMRI Processing

The rs-fMRI workflow includes:

- Reading acquisition metadata such as number of volumes, TR, voxel size and field strength.
- Motion assessment through framewise displacement.
- Registration of tissue masks into fMRI space.
- Brain/background masking.
- Voxelwise nuisance regression using motion parameters, motion derivatives, CSF principal components and white-matter principal components.
- High-pass temporal filtering at 1/128 Hz.
- ROI-level extraction of cleaned BOLD time series.

### 4. Functional Connectivity and Network Analysis

The filtered ROI-level BOLD signals are used to compute:

- Static Pearson functional connectivity.
- Fisher z-transformed connectivity.
- FDR-corrected significant connectivity matrix.
- Node degree from the thresholded connectivity graph.
- Node strength from the thresholded connectivity graph.

### 5. Functional Gradients

Functional gradients are estimated from the cortical functional connectivity matrix using BrainSpace with a Gaussian kernel and Laplacian eigenmaps. The first two gradients are visualized in a low-dimensional cortical organization space and colored by functional network.

### 6. PET-fMRI Multimodal Integration

The final analysis relates FDG-PET metabolism to rs-fMRI network organization by computing Spearman correlations between cortical SUVR and:

- Functional connectivity degree.
- Functional connectivity strength.
- The first functional gradient.

The generated figure summarizes the relationship between glucose metabolism and functional organization across cortical parcels.

## Repository Structure

```text
multimodal-neuroimaging-pet-fmri/
+-- README.md
+-- .gitignore
+-- code/
|   +-- MAIN_FSL_GROUP03.sh
|   +-- MAIN_MATLAB_GROUP03.m
+-- figures/
|   +-- Figure2_TACs.png
|   +-- Figure3_SUVR_stem.png
|   +-- Figure4_FD.png
|   +-- Figure5_design_matrix.png
|   +-- Figure6_BOLD_timeseries.png
|   +-- Figure7_static_FC_zFisher_FDR.png
|   +-- Figure8_degree_strength.png
|   +-- Figure9_Cortical_Functional_Gradients.png
|   +-- Figure10_PET_rsFMRI_integration.png
+-- report/
|   +-- REPORT_GROUP03.pdf
+-- data/
    +-- README.md
```



## Requirements

- MATLAB with Image Processing and Statistics functionality.
- FSL.
- BrainSpace for MATLAB.
- Schaefer 100 parcels atlas with cerebellar reference regions.
- A compatible multimodal T1w, FDG-PET and rs-fMRI dataset.

The FSL script assumes that FSL is available and configured in the execution environment. The MATLAB script assumes that the project folders are organized relative to the `code/` directory.

## Expected Data Layout

The full data are excluded from version control, but the scripts expect a local structure similar to:

```text
data/
+-- anat/
+-- pet/
+-- func/
+-- utils/
    +-- Schaefer_100Parcels_7Networks_Cereb.csv
    +-- fdr_bh.m
    +-- BrainSpace-master/

data_processed/
+-- anat/
+-- pet/
+-- func/
```


## Data Availability

Neuroimaging data are not included in this repository due to their size and possible redistribution restrictions. The repository contains the analysis code, representative figures and report needed to document the workflow. To reproduce the analysis, place the required T1w, FDG-PET, rs-fMRI, atlas and metadata files in the expected local folder structure.

## Outputs

The main generated outputs include:

- PET time-activity curves across functional networks and cerebellum.
- PET motion parameter plots.
- Cortical SUVR estimates.
- fMRI framewise displacement and motion summaries.
- Nuisance regression design matrix.
- ROI-level BOLD time series before and after cleaning/filtering.
- Static functional connectivity matrices before and after FDR correction.
- Degree and strength graph metrics.
- Cortical functional gradient visualization.
- PET-fMRI multimodal integration scatter plots.


