# Marine Invasive Species Distribution Modeling - Supplementary Code

**Supplementary code and data processing scripts for:**

> [Paper Title]  
> [Authors]  
> [Journal], [Year]  
> DOI: [link]

---

## Overview

This repository contains all code used to process data and generate figures for our study on marine invasive species distribution modeling across European waters. We integrate environmental DNA (eDNA) metabarcoding data from genetic observatory networks with species distribution models to predict current and future habitat suitability under climate change scenarios.

---

## Repository Structure

The repository is organized into three main components:

### 1. Environmental Data Processing
Scripts for downloading and preparing Bio-ORACLE environmental layers for species distribution modeling.

- **Location:** `script/pre-modelling/environmental_data/`
- **Scripts:** 01-08 (sequential pipeline)
- **See:** [Environmental Data README](script/pre-modelling/environmental_data/README.md)

**Key outputs:**
- Current conditions (2000-2020): `myExpl_final.tif`, `myExpl_shelf.tif`
- Future projections (2100): SSP 1-2.6, 2-4.5, 5-8.5 scenarios

---

### 2. Occurrence Data Processing
Scripts for downloading, merging, and spatially thinning species occurrence records from GBIF and OBIS.

- **Location:** `script/pre-modelling/occurrence_data/`
- **Scripts:** 01-04 (sequential pipeline)
- **See:** [Occurrence Data README](script/pre-modelling/occurrence_data/README.md)

**Key outputs:**
- Merged occurrence data with duplicates removed
- Spatially thinned occurrences (10 km threshold)

---

### 3. Figure Generation
Scripts for creating all publication figures from modeling results.

- **Location:** `script/figures/`
- **Scripts:** Figure_1.r through Figure_6.R
- **See:** [Figures README](script/figures/README.md)

**Figures:**
1. Model performance analysis
2. Species-level habitat suitability maps
3. Suitability changes under climate change
4. Invasion hotspots (cumulative suitability)
5. Future changes across scenarios
6. Ecoregion-level analysis

---

## Requirements

### R Packages
```r
# Environmental data
install.packages(c("terra", "sf", "usdm", "rnaturalearth", "rnaturalearthdata", "biooracler"))

# Occurrence data
install.packages(c("rgbif", "robis", "spThin", "dplyr", "tidyverse", "lubridate"))

# Figures
install.packages(c("terra", "ggplot2", "sf", "rnaturalearth", "dplyr", 
                   "tidyr", "patchwork", "ggpubr", "grid", "gridExtra", "reshape2"))

# Species distribution modeling (not included in this repo)
install.packages("biomod2")
```

### Data Sources
- **Environmental data:** Bio-ORACLE v3.0 (Assis et al., 2024)
- **Occurrence data:** GBIF and OBIS
- **Ecoregions:** MEOW (Marine Ecoregions of the World)




## Citation

If you use code from this repository, please cite:

**Our paper:**
> [Full citation]

**Bio-ORACLE:**
> Assis, J., Tyberghein, L., Bosch, S., Verbruggen, H., Serrão, E. A., & De Clerck, O. (2024). Bio-ORACLE v3.0. Pushing marine data layers to the CMIP6 Earth system models of climate change research. *Global Ecology and Biogeography*.

**GBIF:**
> GBIF.org (accessed [date]) GBIF Occurrence Download https://doi.org/10.15468/dl.[key]

**OBIS:**
> OBIS (2025) Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org.

---

## Contact

**Justine Pagnier**  
PhD Student, Marine Biology  
University of Gothenburg  
Email: justine.pagnier@gu.se


---

**Last updated:** January 2025
