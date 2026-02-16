## Environmental Data Pipeline

Scripts: `pre-modelling/environmental data/01` through `08`

These scripts download and process environmental predictor layers from
Bio-ORACLE v3.0 for use in species distribution modelling. They produce
two sets of outputs: current conditions (2000–2020 baseline) and future
projections (2100, SSP1-2.6, SSP2-4.5, SSP5-8.5), both clipped to the
continental shelf (≤200m depth).

> ℹ️ **The processed environmental layers used in the published analysis are
> archived on [Fighare](https://figshare.com/s/ab27e1dcaee11ba59e88). If you only want to reproduce the models or figures,
> you can download these directly and skip to the modelling pipeline.**
> Re-running this pipeline from scratch requires a Bio-ORACLE API connection
> and approximately 1–2 hours of processing time.

### Prerequisites

- [ ] R 4.4.1 with the following packages installed:
      `terra`, `biooracler`, `usdm`, `sf`, `rnaturalearth`, `rnaturalearthdata`
- [ ] Active internet connection for Bio-ORACLE downloads (scripts 01 and 06)
- [ ] All scripts run from the same working directory
      (set `setwd()` at the top of each script before running)

### Pipeline overview
```
01_download_biooracle_current.R     → layers/
02_calculate_distance_to_coast.R    → distcoast.tif
03_combine_current_layers.R         → current_layers_raw.tif
04_focal_interpolation_current.R    → current_layers_interpolated.tif
05_vif_analysis.R                   → myExpl_final.tif
                                      selected_var_names.txt
                                      removed_var_names.txt
06_download_biooracle_future.R      → layers_future/
07_process_future_layers.R          → ssp[126|245|585]_layers_final_2100.tif
08_create_shelf_subsets.R           → myExpl_shelf.tif
                                      ssp[126|245|585]_shelf_2100.tif
```

Scripts must be run sequentially. Each script expects outputs from the
previous step to be present in the working directory.

---

### Script 01: Download current Bio-ORACLE layers

Downloads baseline (2000–2020) environmental layers from Bio-ORACLE v3.0
for depth-mean, depth-surface, and terrain variables. Outputs are saved
as `.nc` files organised by depth level in `layers/`.

**Key parameters:**
- Baseline period: 2001–2010 (representative of 2000–2020 conditions)
- Variables: temperature, salinity, oxygen, chlorophyll, pH, nutrients,
  sea ice concentration, wave stress, bathymetry


**Outputs:** `layers/depthmean/*.nc`, `layers/depthsurf/*.nc`,
`layers/terrain/*.nc`

> ℹ️ Downloads may take 30–60 minutes depending on connection speed.
> If a download fails, re-running the script will re-attempt all datasets.

---

### Script 02: Calculate distance to coast

Derives a distance-to-coast layer (km) from the Bio-ORACLE bathymetry
layer. Uses aggregation (factor 4) to speed up the distance calculation,
then disaggregates back to the original resolution.


**Input:** `base.tif` (bathymetry layer extracted from
`layers/terrain/terrain_characteristics_bathymetry_mean.nc`)

**Output:** `distcoast.tif`

> ⚠️ Before running, extract the bathymetry band from the terrain `.nc`
> file and save it as `base.tif` in your working directory:
> ```r
> terrain <- rast("layers/terrain/terrain_characteristics_bathymetry_mean.nc")
> base <- terrain[["bathymetry_mean"]]
> writeRaster(base, "base.tif")
> ```

---

### Script 03: Combine current environmental layers

Stacks all downloaded `.nc` files into a single multi-layer raster, appends
depth level labels to layer names (e.g. `thetao_mean_depthmean`), and adds
the distance-to-coast layer. The `distance_to_land` layer name is used as
a land mask reference throughout the rest of the pipeline — do not rename it.


**Inputs:** `layers/`, `distcoast.tif`

**Output:** `current_layers_raw.tif`

---

### Script 04: Focal interpolation (current layers)

Fills coastal data gaps using a 3×3 focal mean window. Many occurrence
records fall near coastlines where Bio-ORACLE layers have edge artefacts
or missing values. Only NA cells are filled; original values are preserved.

**Input:** `current_layers_raw.tif`

**Output:** `current_layers_interpolated.tif`

> ℹ️ This step may take 15–30 minutes depending on the number of layers
> and available memory.

---

### Script 05: VIF analysis

Removes collinear predictors using stepwise Variance Inflation Factor (VIF)
selection (threshold = 10). Adjusts the final variable set for future
projection compatibility by replacing depth-mean chlorophyll
(`chl_mean_depthmean`) with its surface equivalent and removing PAR
(not available in Bio-ORACLE future projections).

**Input:** `current_layers_interpolated.tif`

**Outputs:**
- `myExpl_final.tif` — final predictor stack for current conditions
- `selected_var_names.txt` — variables retained after VIF selection
- `removed_var_names.txt` — variables removed due to collinearity

> ⚠️ The variable selection from this step is used in all downstream
> scripts. The `selected_var_names.txt` and `removed_var_names.txt` files
> from the published analysis are committed to this repository. If you
> re-run this script, variable selection may differ slightly due to the
> stepwise nature of the VIF algorithm. To exactly reproduce the published
> analysis, use the archived `myExpl_final.tif` from [Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88) rather than
> re-running this script.

---

### Script 06: Download future Bio-ORACLE layers

Downloads future climate projection layers (2100) from Bio-ORACLE v3.0
under three SSP scenarios. Only climate variables are downloaded —
bathymetry and distance to coast are reused from the current conditions
stack (script 05) as they are static.

**Outputs:** `layers_future/ssp126_2100/`, `layers_future/ssp245_2100/`,
`layers_future/ssp585_2100/`

> ℹ️ Downloads may take 30–60 minutes. Failed downloads are logged to the
> console — check for any failures before running script 07.

---

### Script 07: Process future environmental layers

For each SSP scenario: loads downloaded `.nc` files, adds depth labels,
filters to VIF-selected climate variables, applies focal interpolation to
fill coastal gaps, and appends static layers (bathymetry, distance to coast)
from `myExpl_final.tif`.

**Inputs:** `layers_future/`, `myExpl_final.tif`, `selected_var_names.txt`

**Outputs:** `ssp126_layers_final_2100.tif`, `ssp245_layers_final_2100.tif`,
`ssp585_layers_final_2100.tif`

> ⚠️ Variable names and layer order in the future stacks must exactly match
> `myExpl_final.tif`. The script checks for this automatically and will
> warn if any expected variables are missing.

---

### Script 08: Create continental shelf subsets

Clips all environmental stacks to the continental shelf (bathymetry ≥ −200m).
These shelf subsets are the direct inputs to the species distribution
modelling pipeline.

**Inputs:** `myExpl_final.tif`, `ssp[126|245|585]_layers_final_2100.tif`

**Outputs:**
- `myExpl_shelf.tif` → used in modelling steps 1–3
- `ssp126_shelf_2100.tif` → used in modelling step 4
- `ssp245_shelf_2100.tif` → used in modelling step 4
- `ssp585_shelf_2100.tif` → used in modelling step 4

> ℹ️ The shelf definition (≤200m depth) reflects the coastal and benthic
> focus of the study. Deep ocean areas are excluded as the target NIS are
> primarily associated with shallow coastal and port habitats.

---

### Troubleshooting

- **Bio-ORACLE download fails:** Check your internet connection and that
  the `biooracler` package is up to date. Dataset IDs may change between
  Bio-ORACLE versions — verify against the
  [Bio-ORACLE website](https://bio-oracle.org) if downloads fail.
- **Layer name mismatches between current and future stacks:** Ensure
  scripts 03 and 07 use the same depth label convention
  (`_depthmean`, `_depthsurf`). Both scripts append labels from folder
  names, so directory structure must be consistent.
- **Memory errors during focal interpolation:** Reduce `memfrac` in
  `terraOptions()` or process layers in smaller batches.
