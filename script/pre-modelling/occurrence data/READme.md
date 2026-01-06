Readme occurrences · MD
Copier

# Occurrence Data Processing Scripts

This repository contains R scripts used to obtain and process species occurrence data from GBIF and OBIS for the species distribution models presented in [Paper Title/DOI].

## Overview

These scripts download occurrence records from two major biodiversity databases (GBIF and OBIS), merge them, remove duplicates, and apply spatial thinning to reduce sampling bias.

## Scripts

The processing pipeline consists of 4 sequential scripts:

1. **01_get_gbif_data.R** - Download occurrence records from GBIF
2. **02_get_obis_data.R** - Download occurrence records from OBIS
3. **03_merge_both.R** - Merge GBIF and OBIS data, remove duplicate coordinates
4. **04_thinning.R** - Apply spatial thinning (10 km) to reduce sampling bias

Run scripts 01-03 sequentially. Script 04 is designed for parallel execution on HPC clusters.

## Requirements

```r
install.packages(c("rgbif", "robis", "spThin", "dplyr", "tidyverse", "lubridate"))
```

**Note:** Script 01 requires GBIF account credentials (free registration at gbif.org).

## Input

All scripts require a **species_list.csv** file with a column named `Species` containing scientific names.

Example:
```csv
Species
Carcinus maenas
Hemigrapsus sanguineus
Magallana gigas
```

## Key Outputs

**After Script 01 & 02:**
- Individual CSV files per species in `occurrences_0825/`
  - Format: `{species}_gbif_occurrences_YYYY-MM-DD.csv`
  - Format: `{species}_obis_occurrences_YYYY-MM-DD.csv`

**After Script 03:**
- Merged files: `occurrences_0825/occurrences_merged/{species}_merged_YYYY-MM-DD.csv`
- Summary statistics: `occurrences_0825/occurrences_merged/merged_summary_YYYY-MM-DD.csv`

**After Script 04:**
- Thinned files: `occurrences_0825/occurrences_thinned/{species}_merged_thinned_YYYY-MM-DD.csv`
- Summary statistics: `occurrences_0825/occurrences_thinned/thinning_summary.csv`

## Data Filtering

### GBIF (Script 01)
- Date range: 2000-01-01 to 2025-08-01
- No geospatial issues
- Has coordinates
- Occurrence status = PRESENT
- Coordinate uncertainty < 5000m (or NULL)
- Basis of record: HUMAN_OBSERVATION, MACHINE_OBSERVATION, MATERIAL_SAMPLE, OCCURRENCE, OBSERVATION

### OBIS (Script 02)
- Date range: 2000-01-01 to 2025-08-01
- Complete coordinates (no NAs)
- Basis of record: HumanObservation, Occurrence, MaterialSample

### Spatial Thinning (Script 04)
- Algorithm: spThin (Aiello-Lammens et al., 2015)
- Distance threshold: 10 km
- Applied only to presence records
- Random seed: 1000 + task_id (for reproducibility)

## Running Script 04 on HPC

Script 04 is designed for parallel execution using SLURM task arrays:

```bash
# Example SLURM submission for 69 species
#SBATCH --array=1-69
#SBATCH --time=01:00:00
#SBATCH --mem=4G

Rscript 04_thinning.R $SLURM_ARRAY_TASK_ID
```

For local/sequential execution, modify the script to loop over all files.

## Output Data Structure

Each final occurrence file contains:
- `longitude` - Decimal longitude
- `latitude` - Decimal latitude
- `occurrenceStatus` - 1 for presence, 0 for absence
- `source` - "GBIF" or "OBIS"

## Data Sources

**GBIF:**
> GBIF.org (accessed YYYY-MM-DD) GBIF Occurrence Download https://doi.org/10.15468/dl.XXXXXX

**OBIS:**
> OBIS (2025) Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org. Accessed: YYYY-MM-DD

### References

**spThin algorithm:**
> Aiello-Lammens, M. E., Boria, R. A., Radosavljevic, A., Vilela, B., & Anderson, R. P. (2015). spThin: an R package for spatial thinning of species occurrence records for use in ecological niche models. *Ecography*, 38(5), 541-545.

## Contact

Justine Pagnier  
University of Gothenburg  
justine.pagnier@gu.se
