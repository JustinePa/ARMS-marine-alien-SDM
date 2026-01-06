# Species Distribution Modeling Scripts

This repository contains R scripts and SLURM job submission files for running species distribution models using the biomod2 framework. 
These scripts were used to model 69 marine invasive species across European waters for [Paper Title/DOI].

## Overview

The modeling pipeline consists of four main steps:
1. **Individual modeling** - Train multiple algorithms for each species
2. **Ensemble modeling** - Create ensemble models from individual models
3. **Current projections** - Project ensemble models to current conditions
4. **Future projections** - Project to future climate scenarios (SSP 1-2.6, 2-4.5, 5-8.5)

All steps are designed for parallel execution on HPC clusters using SLURM job arrays.

## Scripts

### 1. Individual Modeling
- **modeling_mixedPA.R** - Main modeling script with mixed pseudo-absence strategy
- **modeling_mixedPA_array.slurm** - SLURM array job for parallel processing

**Algorithms:** Random Forest (RF), MAXNET, MARS, GAM, XGBoost  
**Cross-validation:** 5-fold CV  
**Pseudo-absences:** Mixed strategy (disk + random), 20-100 km from presences for the disk method

### 2. Ensemble Modeling
- **ensemble.R** - Create ensemble models from individual algorithms
- **ensemble_array.slurm** - SLURM array job

**Ensemble methods:** EMwmean (weighted mean), EMcv (coefficient of variation), EMca (committee averaging)  
**Selection thresholds:** TSS ≥ 0.6, ROC ≥ 0.85

### 3. Current Projections
- **projection_EM.R** - Project ensemble models to current environmental conditions
- **projection_EM.slurm** - Single projection job
- **projection_EM_array.slurm** - Array job for multiple species

### 4. Future Projections
- **projection_EM_future.R** - Project to future climate scenarios
- **projection_future_EM_array.slurm** - Array job for all scenarios

## Requirements

### R Packages
```r
install.packages(c("biomod2", "terra", "dplyr", "tidyr", "PRROC"))
```

### HPC Environment
- SLURM workload manager
- R 4.4+ with spatial libraries (GDAL, PROJ, GEOS)
- Sufficient memory (scripts use 4 CPUs, ~16-32 GB RAM per task)

## Input Files

### Required Data
1. **Species list:** `species_list.txt` (all species you wish to model) or `species_list_ensemble.txt` (all species that actually got individual models, as some did not get enough occurrence data to be modelled)
2. **Occurrence data:** `occurrences_thinned_0825/{species}_merged_thinned_2025-08-19.csv`
   - Generated from `pre-modelling/occurrence_data/` pipeline
3. **Environmental layers:** 
   - Current: `myExpl_shelf.tif`
   - Future: `ssp126_shelf_2100.tif`, `ssp245_shelf_2100.tif`, `ssp585_shelf_2100.tif`
   - Generated from `pre-modelling/environmental_data/` pipeline

### Input Format
**Occurrence files** must contain:
- `longitude` - Decimal longitude
- `latitude` - Decimal latitude  
- `occurrenceStatus` - 1 for presence, 0 for absence

## Key Parameters

### Modeling (Script 1)
- **PA distance:** 20-100 km from presences
- **CV strategy:** 5-fold cross-validation
- **Algorithms:** RF, MAXNET, MARS, GAM, XGBOOST
- **Cores:** 4 per species

### Ensemble (Script 2)
- **Metric thresholds:** TSS ≥ 0.6, ROC ≥ 0.85
- **Ensemble algorithms:** EMwmean, EMcv, EMca
- **Model selection:** Based on TSS and ROC performance

### Projections (Scripts 3-4)
- **Extent:** Continental shelf (0-200m depth)
- **Output format:** Binary predictions + habitat suitability (0-1)
- **Uncertainty metrics:** Coefficient of variation, committee averaging

## Output Structure

```
project/
├── eval/                           # Individual model outputs
│   └── {species}_mixed_*/
│       ├── {species}.models.out    # biomod2 model object
│       └── individual_eval.csv     # Model evaluation metrics
│
├── EM_mix50/                       # Ensemble models
│   └── full_eval_EM_{species}.csv  # Ensemble evaluation
│
├── current_proj/                   # Current projections
│   └── {species}/
│       ├── EMwmean/
│       ├── EMcv/
│       └── EMca/
│
├── ssp126_proj/                    # Future projections (low)
├── ssp245_proj/                    # Future projections (medium)
└── ssp585_proj/                    # Future projections (high)
```

## Integration with Other Pipelines

**Inputs from:**
- `pre-modelling/environmental_data/` → `myExpl_shelf.tif`, `ssp*_shelf_2100.tif`
- `pre-modelling/occurrence_data/` → `occurrences_thinned_0825/*.csv`

**Outputs to:**
- `figures/` → Model predictions and evaluations
- Post-processing analysis → Stacked suitability maps, uncertainty metrics

## Citation

If you use these scripts, please cite:

**Our paper:**
> [Full citation]

**biomod2:**
> Thuiller, W., Georges, D., Gueguen, M., Engler, R., & Breiner, F. (2023). biomod2: Ensemble Platform for Species Distribution Modeling. R package version 4.2-5.

## Contact

**Justine Pagnier**  
University of Gothenburg  
justine.pagnier@gu.se

---

**Note:** File paths and HPC module versions in SLURM scripts are specific to the Dardel cluster at PDC (KTH). Adjust for your HPC environment.
