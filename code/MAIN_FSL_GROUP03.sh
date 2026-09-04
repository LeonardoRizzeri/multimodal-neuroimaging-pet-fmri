#!/bin/bash

#Load FSL environment
source /nfsd/opt/FSL/fsl.sh

echo "Performing brain segmentation."

Basepath=$(pwd)

# Define the data path
anat_input_path="$Basepath/../data/anat"
pet_input_path="$Basepath/../data/pet"
func_input_path="$Basepath/../data/func"
# Define the output path
anat_output_path="$Basepath/../data_processed_test/anat"
pet_output_path="$Basepath/../data_processed_test/pet"
func_output_path="$Basepath/../data_processed_test/func"


# Create the output directory if it does not already exist
mkdir -p "$anat_output_path"
mkdir -p "$pet_output_path"
mkdir -p "$func_output_path"

# --- TASK 1.1: Brain Segmentation ---
input_t1_brain="sub-s014_ses-open_T1w_brain.nii.gz"
input_t1_raw="sub-s014_ses-open_T1w.nii.gz"

# Perform brain segmentation
fast -t 1 -b -B -v -o $anat_output_path/structural1_fast $anat_input_path/$input_t1_brain
echo "Brain segmentation completed."

# --- TASK 1.1: Thresholding ---
CSF="structural1_fast_pve_0.nii.gz"
GM="structural1_fast_pve_1.nii.gz"
WM="structural1_fast_pve_2.nii.gz"

echo "Perform segmentation thresholding..."
fslmaths $anat_output_path/$CSF -thr 0.6 $anat_output_path/CSF_thresholded_06.nii.gz
fslmaths $anat_output_path/$GM -thr 0.4 $anat_output_path/GM_thresholded_04.nii.gz
fslmaths $anat_output_path/$WM -thr 0.4 $anat_output_path/WM_thresholded_04.nii.gz

# --- TASK 1.2: Masking ---
echo "Create the corrisponding binary masks..."
fslmaths $anat_output_path/CSF_thresholded_06.nii.gz -bin $anat_output_path/CSF_T1w_mask.nii.gz
fslmaths $anat_output_path/GM_thresholded_04.nii.gz -bin $anat_output_path/GM_T1w_mask.nii.gz
fslmaths $anat_output_path/WM_thresholded_04.nii.gz -bin $anat_output_path/WM_T1w_mask.nii.gz
echo "Brain masking completed"
echo "T1w processing completed."


## --- TASK 2.2 : PET motion correction --- 

echo "Performing PET motion correction using FSL mcflirt..."

# Define the input image
input_pet="sub-s014_ses-open_task-rest_pet.nii.gz"

# Perform motion correction
mcflirt -in $pet_input_path/$input_pet -out $pet_output_path/sub-s014_ses-open_task-rest_pet_moco.nii.gz -refvol 18 -plots -report -v
echo "Motion correction completed."

# Extraction of the 19th volume
fslroi $pet_input_path/$input_pet \
       "$pet_output_path/sub-s014_ses-open_task-rest_pet_ref_vol_19.nii.gz" 18 1

echo "Reference volume extracted."


## ---TASK 2.3 : Coregistration of the 19th PET volume to the T1w image ---

input_PETvolume="sub-s014_ses-open_task-rest_pet_ref_vol_19.nii.gz"
flirt -in $pet_output_path/$input_PETvolume \
      -ref $anat_input_path/$input_t1_raw \
      -out $pet_output_path/PET_2_T1w.nii.gz \
      -omat $pet_output_path/PET_2_T1w.mat \
      -cost corratio \
      -interp trilinear \
      -dof 6 \
      -v

## --- TASK 2.3: Coregistrazione PET to T1w ---

echo "Inverting transformation matrix: T1w to PET..."

convert_xfm -omat "$pet_output_path/T1w_2_PET.mat" -inverse "$pet_output_path/PET_2_T1w.mat"

echo "Bringing tissue masks into PET space..."
# GM mask
flirt -in "$anat_output_path/GM_T1w_mask.nii.gz" \
      -ref "$pet_output_path/sub-s014_ses-open_task-rest_pet_ref_vol_19.nii.gz" \
      -applyxfm -init "$pet_output_path/T1w_2_PET.mat" \
      -out "$pet_output_path/GM_mask_2_PETspace.nii.gz" \
      -interp nearestneighbour

# WM mask
flirt -in "$anat_output_path/WM_T1w_mask.nii.gz" \
      -ref "$pet_output_path/sub-s014_ses-open_task-rest_pet_ref_vol_19.nii.gz" \
      -applyxfm -init "$pet_output_path/T1w_2_PET.mat" \
      -out "$pet_output_path/WM_mask_2_PETspace.nii.gz" \
      -interp nearestneighbour

# CSF mask
flirt -in "$anat_output_path/CSF_T1w_mask.nii.gz" \
      -ref "$pet_output_path/sub-s014_ses-open_task-rest_pet_ref_vol_19.nii.gz" \
      -applyxfm -init "$pet_output_path/T1w_2_PET.mat" \
      -out "$pet_output_path/CSF_mask_2_PETspace.nii.gz" \
      -interp nearestneighbour
      
      
      


#TASK 3.3   (Coregistion of CSF,WM,GM mask into fmri space)

convert_xfm \
    -inverse "$func_input_path/sub-s014_ses-open_task-rest_bold_SlTi_moco_brain_2_T1.mat" \
    -omat "$func_output_path/sub-s014_ses-open_T1w_2_fMRI.mat"

# Define fMRI reference image
# The output masks will have the same space, size and resolution of this image
fmri_ref="$func_input_path/sub-s014_ses-open_task-rest_bold_SlTi_moco_brain.nii.gz"


echo "Performing registration of CSF mask to fMRI space"

flirt \
    -interp nearestneighbour \
    -v \
    -in "$anat_output_path/CSF_T1w_mask.nii.gz" \
    -ref "$fmri_ref" \
    -applyxfm \
    -init "$func_output_path/sub-s014_ses-open_T1w_2_fMRI.mat" \
    -out "$func_output_path/CSF_mask_2_fMRIspace.nii.gz"


echo "Performing registration of Gray Matter mask to fMRI space"

flirt \
    -interp nearestneighbour \
    -v \
    -in "$anat_output_path/GM_T1w_mask.nii.gz" \
    -ref "$fmri_ref" \
    -applyxfm \
    -init "$func_output_path/sub-s014_ses-open_T1w_2_fMRI.mat" \
    -out "$func_output_path/GM_mask_2_fMRIspace.nii.gz"


echo "Performing registration of White Matter mask to fMRI space"

flirt \
    -interp nearestneighbour \
    -v \
    -in "$anat_output_path/WM_T1w_mask.nii.gz" \
    -ref "$fmri_ref" \
    -applyxfm \
    -init "$func_output_path/sub-s014_ses-open_T1w_2_fMRI.mat" \
    -out "$func_output_path/WM_mask_2_fMRIspace.nii.gz"

echo "coregistrazioni completate"

