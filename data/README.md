# Data

The raw and processed neuroimaging data are intentionally excluded from this repository.

This project expects a local multimodal dataset organized as:

```text
data/
+-- anat/
+-- pet/
+-- func/
+-- utils/
```

and processed outputs organized as:

```text
data_processed/
+-- anat/
+-- pet/
+-- func/
```

The excluded files include subject-level T1w, FDG-PET and rs-fMRI NIfTI files, derived tissue masks, registration outputs, motion-corrected images and other intermediate processing results.

These files are not tracked on GitHub because they are large and may be subject to dataset license, consent or privacy restrictions. To reproduce the analysis, obtain the appropriate dataset from the original authorized source and place the required files in the expected local folders before running the scripts.

Expected supporting resources include the Schaefer 100 parcels atlas labels, an FDR correction helper and a local BrainSpace installation. BrainSpace should preferably be installed as an external dependency rather than committed inside this repository.
