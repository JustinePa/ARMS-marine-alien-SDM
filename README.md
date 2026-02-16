# Marine Alien Species Distribution Modeling

**Scripts used for data collection, modelling, analysis and visualisation in:**

> Pagnier, J., Andermann, T., Andersson, M.G., Obst, M. (2026). 
> The role of genetic observatory networks in the detection and 
> forecasting of marine non-indigenous species.
> DOI preprint: https://doi.org/10.21203/rs.3.rs-8702791/v1

---

## Overview

This repository contains all code used to process data and generate figures for our study on marine non-indigenous species (NIS) distribution modelling across European waters. We integrate metabarcoding data from genetic observatory networks (ARMS-MBON) with ensemble species distribution models to predict current and future habitat suitability for 69 NIS under three climate change scenarios (SSP1-2.6, SSP2-4.5, SSP5-8.5) through 2100.

---

## Repository structure

```
script/
├── pre-modelling/
│   ├── environmental data/     # Bio-ORACLE data download and preparation (8 scripts)
│   └── occurrence data/        # GBIF/OBIS download, merge, and thinning (4 scripts)
├── modelling/                  # biomod2 ensemble SDM pipeline (4 scripts + SLURM)
├── post-modelling processing/  # SDM output processing and ecoregion analysis (1 script)
├── figures/                    # Publication figure generation (6 scripts)
└── contingency.areas.computing/ # Ballast water contingency area analysis (4 scripts)
```

Each subdirectory contains its own `README.md` with detailed instructions.

---

## Quick demo

Pre-processed occurrence data and environmental layers for all 69 species 
are available at [Figshare DOI](https://figshare.com/s/ab27e1dcaee11ba59e88).

**Minimum demo (reproducing figures):**
All scripts in `script/figures/` and `script/contingency.areas.computing/` 
can be run on data found in [Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88).
Set `base_dir` at the top of each script to your local directory containing 
the downloaded Figshare data.
Expected output: all manuscript figures saved to `base_dir/figures/`
Runtime is a few minutes per script

**Extended demo — modelling pipeline (2–3 hours, HPC recommended):**
1. Download occurrence CSVs and environmental layers from [Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88)
   Species occurrences files follow this pattern `<species>_merged_thinned_2025-08-19.csv` in folder `/occurrences_0825`
   Environmental layers are in the file `myExpl_shelf.tif` from `input/environmental_data.zip` in the [Figshare repo](https://figshare.com/s/ab27e1dcaee11ba59e88)
2. Run species distribution models for 2–3 species by setting `SPECIES_LIST` 
   in `script/modelling/01_modeling_mixedPA_array.slurm` to e.g. 
   `c("Crepidulafornicata", "AcartiaAcanthacartiatonsa")`
   In this same slurm script, edit:
   `#SBATCH -A` (your project ID),
   `#SBATCH --array=` ("1-2" for 2 species),
   `cd` (your working directory where model outputs will be created)
   `MODELING_DATE` which is the date of the analysis and will be used throughout the workflow
3. Expected output: per-species suitability rasters in
   folders with species names (e.g. `/Crepidulafornicata/`) as per BIOMOD2 default . Model evaluation 
   metrics (TSS, AUC) in `eval/{SpeciesName}_mixed_myExpl_shelf_kfold/`
   Expected run time: 30–60 minutes per species on HPC (1 CPU core)


> **No HPC access?** The modelling scripts can be run locally in R by 
> passing arguments directly instead of using SLURM. For example, to run 
> script 01 for *Crepidula fornicata* locally:
> ```r
> Args <- c(
>   "Crepidulafornicata",              # species code
>   "RF,GAM,MARS,MAXENT,XGBOOST",      # algorithms
>   "20",                              # PA_dist_min (km)
>   "100",                             # PA_dist_max (km)
>   "kfold",                           # CV_strategy
>   "3",                               # CV_nb_rep
>   "NULL",                            # CV_perc_or_NULL
>   "5",                               # CV_k_or_NULL
>   "1",                               # n_cores — use 1 on a local desktop (RAM is typically the limiting factor; ensure at least 8 GB available)
>   "path/to/myExpl_shelf.tif",        # env_file
>   "path/to/output/",                 # outdir
>   "2025-09-24"                       # modeling_date to update
> )
> # uncomment the debugging line at the top of the script:
> # args <- Args
> source("script/modelling/01_modeling_mixedPA_array.R")
> ```
> Expected run time per species on a standard desktop: 2–4 hours.

Full reproduction of all manuscript results requires the complete pipeline 
on all 69 species as described below.

---

## Pipelines

### 1. Environmental data
Downloads Bio-ORACLE v3.0 environmental layers, calculates distance-to-coast,
applies focal interpolation to fill coastal gaps, runs VIF analysis for variable
selection, and produces final raster stacks for current conditions and three
future scenarios. Runs locally on PC.

- **Location:** `script/pre-modelling/environmental data/`
- **Scripts:** `01` through `08` (sequential)
- **Key outputs:** `myExpl_final.tif`, `myExpl_shelf.tif`, future scenario stacks

### 2. Occurrence data
Downloads presence records from GBIF and OBIS, merges and deduplicates across
sources, and applies 10 km spatial thinning. Scripts 01–03 run locally; script
04 runs on the HPC cluster as a SLURM array job.

- **Location:** `script/pre-modelling/occurrence data/`
- **Scripts:** `01` through `04` (sequential)
- **Key outputs:** Spatially thinned occurrence CSVs per species

### 3. Species distribution modelling
Runs biomod2 ensemble models, projects current and future habitat suitability,
and produces EMwmean and EMca outputs per species. Runs on HPC cluster (Dardel,
PDC KTH) using SLURM array jobs.

- **Location:** `script/modelling/`
- **Scripts:** `01` through `04` (sequential, each with a `.slurm` companion)
- **Key outputs:** Per-species suitability rasters for all scenarios

> ℹ️ The full modelling pipeline (~200 CPU hours for 69 species) is 
> designed for HPC execution. For a small-scale test on 2–3 species, 
> see the Quick demo section above. Download pre-computed outputs from 
> [Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88) to reproduce 
> figures without re-running models.

### 4. Post-modelling processing
Applies land and ecoregion masking, normalises outputs, computes species stacks,
delta maps, and ecoregion-scale statistics. Runs locally on PC using outputs
downloaded from the HPC cluster.

- **Location:** `script/post-modelling processing/`
- **Script:** `post-mod processing.R`
- **Key outputs:** Normalised rasters, stacked suitability maps, delta maps,
  `ecoregion_mean_delta.csv`

### 5. Figures
Produces all six manuscript figures from post-modelling outputs. All scripts
run locally on PC.

- **Location:** `script/figures/`
- **Scripts:** `figure_01.R` through `figure_06.R`
- **Key outputs:** `Figure_1.pdf` through `Figure_6.png` in `figures/`

### 6. Ballast water contingency areas
Identifies cold spots — areas of low NIS introduction risk outside existing
protected areas and offshore infrastructure — for ballast water management
prioritisation. Runs locally on PC via a master script orchestrating three
sequential subscripts.

- **Location:** `script/contingency.areas.computing/`
- **Master script:** `cold.spot.masterscript.R`
- **Key outputs:** Cold spot polygons, two-panel publication figure

---

## Requirements

### R version
R 4.4.1

### Packages
```r
# Environmental data
install.packages(c("terra", "sf", "usdm", "rnaturalearth", 
                   "rnaturalearthdata", "biooracler"))

# Occurrence data
install.packages(c("rgbif", "robis", "spThin", "dplyr", "lubridate"))

# Modelling (HPC only)
install.packages("biomod2")

# Post-modelling and figures
install.packages(c("terra", "ggplot2", "sf", "rnaturalearth", "dplyr",
                   "tidyr", "tidyverse", "patchwork", "ggpubr", "scales",
                   "readr", "grid", "RColorBrewer"))

# Contingency areas
install.packages(c("terra", "raster", "sf", "dplyr", "stars", "fBasics"))
```

### Data sources
- **Environmental layers:** Bio-ORACLE v3.0 (Assis et al., 2024) —
  downloaded automatically by the environmental data pipeline
- **Occurrence data:** GBIF and OBIS — downloaded automatically by the
  occurrence data pipeline (GBIF account required)
- **Ecoregions:** MEOW shapefile — available from
  [Marine Regions](https://www.marineregions.org)
- **Processed outputs:** Archived in [[this repository](https://figshare.com/s/ab27e1dcaee11ba59e88)] — download to skip modelling
  and run figures directly

---

## Reproducing the analysis

**To reproduce everything from scratch:**
1. Environmental data pipeline (local)
2. Occurrence data pipeline (local → HPC)
3. Modelling pipeline (HPC)
4. Transfer outputs from HPC to local machine
5. Post-modelling processing (local)
6. Figures (local)
7. Contingency areas (local)

**To reproduce figures only:**
1. Download processed outputs from [[this repository](https://figshare.com/s/ab27e1dcaee11ba59e88)]
2. Run `script/figures/figure_01.R` through `figure_06.R`
3. Run `script/contingency.areas.computing/cold.spot.masterscript.R`

Set `base_dir` at the top of each script to your local directory.

---

## Citation

If you use code from this repository, please cite:

**Our paper:**
> Pagnier, J., Andermann, T., Andersson, M.G., Obst, M. ([Year]). 
> The role of genetic observatory networks in the detection and 
> forecasting of marine non-indigenous species. [Journal]. 
> DOI preprint: https://doi.org/10.21203/rs.3.rs-8702791/v1

**Bio-ORACLE:**
> Assis, J., Tyberghein, L., Bosch, S., Verbruggen, H., Serrão, E. A., & De Clerck, O. (2024). Bio-ORACLE v3.0. Pushing marine data layers to the CMIP6 Earth system models of climate change research. *Global Ecology and Biogeography*.

**GBIF:**
> GBIF.org (accessed [date]) GBIF Occurrence Download https://doi.org/10.15468/dl.[key]

**OBIS:**
> OBIS (2025) Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org.

---

## Contact

**Justine Pagnier**  
PhD Student, Marine Sciences  
University of Gothenburg

justine.pagnier@gu.se
