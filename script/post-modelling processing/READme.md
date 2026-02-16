## Post-modelling processing

Script: `post-modelling processing/post-mod processing.r`

This script processes the raw SDM projection outputs downloaded from the HPC
cluster into analysis-ready maps and statistics. It runs locally on your PC
and must be run after downloading all projection outputs from the cluster
(Steps 3 and 4 of the modelling pipeline).

> ℹ️ **The processed outputs used in the published analysis are archived
> on [Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88). If you only want to reproduce the figures, download these
> directly and skip to the figure scripts.**

### Prerequisites

- [ ] R 4.4.1 with the following packages installed:
      `terra`, `dplyr`, `tools`, `ggplot2`, `tidyr`, `scales`, `readr`,
      `tidyterra`, `patchwork`, `sf`
- [ ] Projection outputs downloaded from the HPC cluster (Steps 3 and 4)
- [ ] EMca projection outputs downloaded from the HPC cluster
- [ ] EMcv projection outputs downloaded from the HPC cluster
- [ ] MEOW ecoregion shapefile (`meow_ecos.shp`), available from
      [Marine Regions](https://www.marineregions.org) or
      [Resource Watch](https://resourcewatch.org)
- [ ] `alien_species_regions.csv` — maps each species to its introduced
      ecoregions (Supplementary File 5 of the manuscript)

### Setup

Set `base_dir` at the top of the script to your local directory containing
the downloaded projection outputs:
```r
base_dir <- "path/to/your/working/directory"  # EDIT: set once here
```

### Required input directory structure

Before running, organise your downloaded files as follows:
```
base_dir/
├── current_proj/               # EMwmean outputs from 03_projection_EM.R
│   └── *.tif
├── ssp126_proj/                # EMwmean outputs from 04_projection_EM_future.R
│   └── *.tif
├── ssp245_proj/
│   └── *.tif
├── ssp585_proj/
│   └── *.tif
├── EMca/                       # EMca outputs from Steps 3 and 4
│   ├── current/
│   ├── ssp126/
│   ├── ssp245/
│   └── ssp585/
├── EMcv/                       # EMcv outputs from Steps 3 and 4
│   ├── current/
│   ├── ssp126/
│   ├── ssp245/
│   └── ssp585/
├── MEOW/
│   └── meow_ecos.shp
├── post_modelisation/
│   └── alien_species_regions.csv
└── env_data/
    └── myExpl_shelf.tif        # copy from your HPC working directory
```

### Pipeline overview

| Step | Description | Key outputs |
|------|-------------|-------------|
| 1 | Land masking | `{sc}_proj/masked/MASKED_*.tif` |
| 2 | MEOW ecoregion masking | `{sc}_proj/masked/alien/ALIENMASK_*.tif` |
| 3 | Normalization (0–1000 → 0–1) | `{sc}_proj/masked/alien/normalized/*_norm01.tif` |
| 4 | Species stacking | `{sc}_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_{sc}.tif` |
| 5 | Per-species delta maps | `{sc}_proj/masked/alien/deltas_norm01/*_delta_norm01.tif` |
| 6 | Aggregated delta maps | `continuous_changes_norm01/delta_mean_{sc}_vs_current_norm01.tif` |
| 7 | EMca normalization | `EMca/EMca_normalized/{sc}/*.tif` |
| 8 | Ecoregion statistics | `ecoregion_analysis/ecoregion_mean_delta.csv` |

All steps loop over the four scenarios (`current`, `ssp126`, `ssp245`,
`ssp585`) unless noted otherwise.

---

### Step 1: Land masking

Removes land cells from EMwmean projection rasters using the
`distance_to_land` layer from `myExpl_shelf.tif` as the ocean boundary.
Processes all four scenarios.

**Input:** `{sc}_proj/{SpeciesName}/proj_*EM_{SpeciesName}_{ModelingID}/*.tif`

**Output:** `{sc}_proj/masked/MASKED_*.tif`

---

### Step 2: MEOW ecoregion masking

Clips each species' suitability map to its introduced range using
Marine Ecoregions of the World (MEOW) polygons. Species-to-ecoregion
assignments are read from `alien_species_regions.csv`. Species assigned
`all_metro_europe` in the CSV are masked to all 18 European ecoregions.

**Input:** `{sc}_proj/masked/MASKED_*.tif`, `meow_ecos.shp`,
`alien_species_regions.csv`

**Output:** `{sc}_proj/masked/alien/ALIENMASK_*.tif`

> ℹ️ The `alien_species_regions.csv` file is provided as Supplementary
> File 5 of the manuscript. Each row maps a species name to one or more
> MEOW ecoregion names (semicolon-separated).

---

### Step 3: Normalization

Rescales individual species suitability maps from the biomod2 output
scale (0–1000) to 0–1 for comparison and aggregation across species.
Uses `clamp()` to handle any values outside the theoretical range.

**Input:** `{sc}_proj/masked/alien/ALIENMASK_*.tif`

**Output:** `{sc}_proj/masked/alien/normalized/*_norm01.tif`

> ℹ️ Outputs are compressed with LZW and written as 32-bit floats to
> manage disk space.

---

### Step 4: Species stacking

Computes mean habitat suitability across all species per pixel for each
scenario, producing a multi-species invasion pressure map. Only the 69
species listed in `species_to_stack` are included, matching the published
analysis.

**Input:** `{sc}_proj/masked/alien/normalized/*_norm01.tif`

**Output:** `{sc}_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_{sc}.tif`

**Used in:** Figure 2 (mean current suitability map) and Figure 3
(mean future suitability maps per scenario).

---

### Step 5: Per-species delta maps

Computes future minus current habitat suitability for each species and
scenario, producing change maps in normalized units (range −1 to +1).
Only species present in both current and future normalized outputs are
included.

**Input:** `{sc}_proj/masked/alien/normalized/*_norm01.tif` (current and future)

**Output:** `{sc}_proj/masked/alien/deltas_norm01/*_{sc}_delta_norm01.tif`

---

### Step 6: Aggregated delta maps

Averages per-species delta maps across all species to produce a single
mean suitability change map per scenario. Also produces a trinary
classification (gain / no change / loss) using a ±0.05 threshold.

**Input:** `{sc}_proj/masked/alien/deltas_norm01/*_delta_norm01.tif`

**Outputs:**
- `continuous_changes_norm01/delta_mean_{sc}_vs_current_norm01.tif`
  — continuous mean change map
- `continuous_changes_norm01/delta_mean_{sc}_vs_current_norm01_trinary.tif`
  — classified as gain (+1), no change (0), or loss (−1)

**Used in:** Figure 4 (aggregated suitability change maps).

> ℹ️ The no-change threshold (±0.05) and aggregation function (`mean`)
> can be adjusted via `no_change_band` and `agg_fun` at the top of
> this section.

---

### Step 7: EMca normalization

Rescales EMca (committee averaging) outputs from 0–1000 to 0–1, matching
the scale of the EMwmean outputs processed in Step 3. Skips files that
already exist.

**Input:** `EMca/{sc}/*_EMca*.tif`

**Output:** `EMca/EMca_normalized/{sc}/*.tif`

**Used in:** Figure 5 (model agreement maps).

---

### Step 8: Ecoregion statistics

Calculates area-weighted mean habitat suitability change per MEOW
ecoregion and scenario, using per-species delta maps from Step 5.
Produces the summary statistics reported in Figure 6 and Supplementary
Table X.

**Input:** `{sc}_proj/masked/alien/deltas_norm01/*_delta_norm01.tif`,
`meow_ecos.shp`

**Output:** `ecoregion_analysis/ecoregion_mean_delta.csv`

Columns: `scenario`, `ecoregion`, `mean_delta`, `weighted_mean_delta`,
`min_delta`, `max_delta`, `sd_delta`

**Used in:** Figure 6 (ecoregion-level suitability change).

---

### Troubleshooting

- **"No EMwmeanByTSS rasters found":** Check that your projection
  outputs follow the expected directory structure and that the
  `{ModelingID}` in folder names matches what was used in the modelling
  pipeline.
- **"No alien-region row for species in CSV":** The species name in
  `alien_species_regions.csv` must match exactly the canonical name in
  the `species_list` vector at the top of the script (case-sensitive,
  with spaces).
- **"No normalized rasters in...":** Step 3 must complete for all four
  scenarios (including `current`) before running Steps 5 and 6.
- **Memory errors:** Reduce `memfrac` in `terraOptions()` at the top
  of the relevant section, or process scenarios one at a time by
  commenting out scenarios from the loop vectors.
