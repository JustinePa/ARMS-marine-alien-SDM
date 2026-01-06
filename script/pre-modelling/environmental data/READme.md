# Environmental Data Processing Scripts

This repository contains R scripts used to obtain and process environmental predictor layers for the species distribution models presented in [Paper Title/DOI].

## Overview

These scripts download environmental data from Bio-ORACLE, process it for use in marine species distribution modeling, and create environmental layers for current (2000-2020) and future (2100, SSP126/SSP245/SSP585) climate conditions.

## Scripts

The processing pipeline consists of 8 sequential scripts:

1. **01_download_biooracle_current.R** - Download baseline environmental layers (2000-2020)
2. **02_calculate_distance_to_coast.R** - Calculate distance to coast from bathymetry
3. **03_combine_current_layers.R** - Combine downloaded layers into a single stack
4. **04_focal_interpolation_current.R** - Fill coastal data gaps using focal interpolation
5. **05_vif_analysis.R** - Remove collinear predictors (VIF > 10)
6. **06_download_biooracle_future.R** - Download future climate projections (SSP 1-2.6, 2-4.5, 5-8.5)
7. **07_process_future_layers.R** - Process future layers (filter to VIF-selected variables and interpolate to match current conditions layers)
8. **08_create_shelf_subsets.R** - Create continental shelf subsets (bathymetry ≥ -200m) for modelling coastal species

Run scripts sequentially. Detailed methods are described in the associated publication.

## Requirements

```r
install.packages(c("terra", "sf", "usdm", "rnaturalearth", "rnaturalearthdata", "biooracler"))
```

## Key Outputs

**Current conditions:**
- `myExpl_final.tif` - Full ocean extent
- `myExpl_shelf.tif` - Continental shelf only

**Future conditions (2100):**
- `ssp126_layers_final_2100.tif` / `ssp126_shelf_2100.tif`
- `ssp245_layers_final_2100.tif` / `ssp245_shelf_2100.tif`
- `ssp585_layers_final_2100.tif` / `ssp585_shelf_2100.tif`

**Reference:**
- `selected_var_names.txt` - Variables retained after VIF analysis

## Data Source

Environmental data from Bio-ORACLE v3.0 (Assis et al., 2024):
> Assis, J., Tyberghein, L., Bosch, S., Verbruggen, H., Serrão, E. A., & De Clerck, O. (2024). Bio-ORACLE v3.0. Pushing marine data layers to the CMIP6 Earth system models of climate change research. *Global Ecology and Biogeography*.

## Contact

Justine Pagnier  
University of Gothenburg  
justine.pagnier@gu.se
