## Figure Scripts

Scripts: `figures/figure_01.R` through `figures/figure_06.R`

These scripts produce all manuscript figures from the post-modelling outputs.
All scripts run locally on your PC. Before running, set `base_dir` at the top
of each script to your local directory containing the post-modelling outputs.

### Prerequisites

- [ ] R 4.4.1 with the following packages installed:
      `terra`, `ggplot2`, `sf`, `rnaturalearth`, `dplyr`, `tidyr`, `tidyverse`,
      `patchwork`, `ggpubr`, `scales`, `readr`, `grid`, `patchwork`
- [ ] Post-modelling outputs produced by `post-mod processing.R` or
      downloaded from [[Figshare]](https://figshare.com/s/ab27e1dcaee11ba59e88)
- [ ] `individual_models_all_diagnostics.csv` and `ThinningSummary.csv` — provided in the `figures/`
      folder of this repository (Figure 1 only), inferred from data found in the [[Figshare repository]](https://figshare.com/s/ab27e1dcaee11ba59e88)
- [ ] MEOW ecoregion shapefile (`meow_ecos.shp`) — available from
      [Marine Regions](https://www.marineregions.org) (Figures 2–3 and 6)

### Setup

Set `base_dir` at the top of each script to your local directory:

```r
base_dir <- "path/to/your/working/directory"  # EDIT: set once here
```

All outputs are saved to `base_dir/figures/` which is created automatically.

### Figure overview

| Script | Figure | Description | Key inputs |
|--------|--------|-------------|------------|
| `figure_01.R` | Figure 1 | Model performance: TSS and AUC vs occurrence count | `individual_models_all_diagnostics.csv` |
| `figure_02.R` | Figure 2 | Per-species suitability, uncertainty, and model agreement (2 example species, current) | `EMcv/`, `EMca/`, normalized projections |
| `figure_03.R` | Figure 3 | Per-species suitability change and habitat transitions (2 example species, SSP2-4.5) | Normalized projections (current + ssp245) |
| `figure_04.R` | Figure 4 | Multi-species mean habitat suitability map (current, discrete categories) | `stacked_norm01/` |
| `figure_05.R` | Figure 5 | Multi-species mean suitability change maps (all 3 scenarios, 2×2 layout) | `stacked_norm01/` |
| `figure_06.R` | Figure 6 | Ecoregion-scale suitability change: grouped bar charts + summary tables | `stacked_norm01/`, `meow_ecos.shp` |

---

### Figure 1: Model performance analysis

Scatter plot of TSS and AUC against occurrence count (panel a) and standard
deviation of model performance by sample size category (panel b). Shows how
model performance varies with data availability across the 69 study species.

**Input:** `figures/individual_models_all_diagnostics.csv`

This file aggregates per-species evaluation CSVs from the modelling pipeline.
It is provided directly in the repository so you do not need to re-run the
aggregation step. Note: the ROC metric from biomod2 is renamed AUC in this
file for clarity.

**Output:** `figures/Figure_1.pdf` (submission), `Figure_1_preview.png`,
`Figure_1.svg`

---

### Figure 2: Species-level suitability and uncertainty (current)

Three-panel figure for two example species (*Crepidula fornicata* and
*Acartia tonsa*) showing: (a) habitat suitability, (b) coefficient of
variation in suitable areas (S > 0.3), and (c) model agreement (EMca).
Current climate conditions only.

**Inputs:**
- `EMcv/{current}/masked_emcv_alien/ALIENMASK_{SpeciesCode}_EMcvByTSS*.tif`
- `current_proj/masked/alien/normalized/ALIENMASK_MASKED_{SpeciesCode}*norm01.tif`
- `EMca/EMca_normalized/current/{SpeciesCode}_EMcaByTSS*.tif`

**Output:** `figures/2species_3panel_CV_EMca_masked_new.png`

> ℹ️ This figure is produced for two hardcoded example species. To generate
> equivalent plots for other species, update `species_list` at the top of
> the script.

---

### Figure 3: Species-level suitability change and habitat transitions (SSP2-4.5)

Two-panel figure for the same two example species showing: (a) discrete
change in suitability between current and SSP2-4.5 (2100), and (b)
suitability transition categories (remains suitable / becomes suitable /
becomes unsuitable / remains unsuitable) using a threshold of S = 0.5.

**Inputs:**
- `current_proj/masked/alien/normalized/ALIENMASK_MASKED_{SpeciesCode}*norm01.tif`
- `ssp245_proj/masked/alien/normalized/ALIENMASK_MASKED_{SpeciesCode}*norm01.tif`

**Output:** `figures/2species_change_and_transitions_ssp245_new.png`

> ℹ️ Compares current vs SSP2-4.5 only. To compare with other future
> scenarios, update `scenarios_needed[2]` at the top of the script.

---

### Figure 4: Multi-species mean habitat suitability map (current)

Single-panel map of mean habitat suitability across all 69 species under
current climate, classified into 10 discrete categories from negligible
(S < 0.1) to critical (S > 0.9). Categories reflect management priority
levels for non-indigenous species.

**Input:**
`current_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_current.tif`

**Output:** `figures/Figure_4.png`

> ℹ️ To produce equivalent maps for future scenarios, change `scenario_name`
> at the top of the script to `"ssp126"`, `"ssp245"`, or `"ssp585"`.

---

### Figure 5: Multi-species mean suitability change maps (all scenarios)

Three change maps in a 2×2 layout (three panels + shared legend) showing
mean suitability change across all 69 species relative to current conditions,
for SSP1-2.6, SSP2-4.5, and SSP5-8.5 (2100). Changes classified into 7
discrete categories from major decrease to major increase.

**Inputs:**
- `current_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_current.tif`
- `ssp126_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp126.tif`
- `ssp245_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp245.tif`
- `ssp585_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp585.tif`

**Output:** `figures/Figure_5.png`

---

### Figure 6: Ecoregion-scale suitability change

Side-by-side grouped bar charts showing percentage change (panel a) and
absolute change (panel b) in mean habitat suitability per MEOW ecoregion
across all three scenarios, with error bars showing standard deviation.
Ecoregions ordered by centroid latitude. Also produces two summary CSV
tables.

**Inputs:**
- `stacked_norm01/new_stack_mean_norm01_{scenario}.tif` for all 4 scenarios
- `MEOW/meow_ecos.shp`

**Outputs:**
- `figures/Figure_6.png`
- `figures/ecoregion_dual_metrics_table.csv` — per-ecoregion statistics
  for all scenarios
- `figures/ecoregion_dual_metrics_summary.csv` — cross-ecoregion mean and
  SD per scenario

> ⚠️ This script extracts raster values for all 18 ecoregions across 4
> scenarios. Runtime is approximately 10–20 minutes depending on system
> memory. Adding `terraOptions(memfrac = 0.5)` at the top of the script
> can help if memory errors occur.
.
