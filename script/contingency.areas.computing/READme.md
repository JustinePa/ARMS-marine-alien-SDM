## Ballast Water Contingency Areas (Cold Spot Analysis)

Scripts: `cold.spot.masterscript.R`, `cold.spot.prepare.data.R`,
`cold.spot.calculate.cold.spots.R`, `cold.spot.make.plots.R`

These scripts identify priority areas for ballast water management by
combining multi-species habitat suitability predictions with spatial layers
for Marine Protected Areas (MPAs), Offshore Wind Farms (OWFs), and the
coastline. Areas meeting all threshold criteria simultaneously are defined
as "cold spots" (locations where NIS introduction risk is low and
management intervention is feasible).

All four scripts run locally on your PC. Only the master script needs to
be run directly, it calls the three subscripts automatically.

### Prerequisites

- [ ] R 4.4.1 with the following packages installed:
      `terra`, `raster`, `sf`, `dplyr`, `stars`
- [ ] Post-modelling outputs: stacked mean suitability raster
      (`new_stack_mean_norm01_current.tif`) produced by the post-modelling
      pipeline or downloaded from the [Figshare repository](https://figshare.com/s/ab27e1dcaee11ba59e88)
- [ ] `Datalayers/` folder containing:
      - `windfarmspolyPolygon.shp` — offshore wind farm polygons obtained from [EMODnet](https://emodnet.ec.europa.eu/geoviewer/#)
      - `wdpa_raster_europe.tif` — Marine Protected Areas raster obtained from the [World Database of Protected Areas](https://www.protectedplanet.net/en/thematic-areas/wdpa?tab=WDPA)
      - `ref-countries-2020-01m.shp/CNTR_RG_01M_2020_4326.shp` — country
        boundaries (Eurostat, available at [ec.europa.eu/eurostat](https://ec.europa.eu/eurostat))
      - `chl_baseline_2000_2018_depthmean_chl_mean_1.tif` — coastline
        reference raster (from Bio-ORACLE, used to define the ocean mask)
      - `new_stack_mean_norm01_current.tif` — stacked suitability raster
      
> ℹ️ The complete `Datalayers/` folder used in the published analysis 
> is archived in the [Figshare repository](https://figshare.com/s/ab27e1dcaee11ba59e88).
> Download and place it in the same directory as the cold spot scripts.

### Setup

All scripts must be run from the directory containing the cold spot scripts
and the `Datalayers/` folder. Set your working directory before running:

```r
setwd("path/to/cold_spot_scripts/")
source("cold.spot.masterscript.R")
```

All input paths and threshold parameters are configured at the top of
`cold.spot.masterscript.R` — this is the only file you need to edit.

### Pipeline overview

```
cold.spot.masterscript.R
├── cold.spot.prepare.data.R     → cropped rasters + distance layers (.tif, .rda)
├── cold.spot.calculate.cold.spots.R  → cold spot polygons (.rda)
└── cold.spot.make.plots.R       → publication figure (.pdf)
```

Intermediate outputs are cached — if output files already exist, the
subscripts skip recomputation. To force recalculation, delete the relevant
intermediate files or rename them in the master script.

---

### Configuration

All parameters are set in `cold.spot.masterscript.R`. There are two
sections to edit:

**Study area extent** (section: `CONFIGURATION: Input Data Layers`):
```r
xlim <- c(-5, 30)   # longitude range (°E)
ylim <- c(50, 70)   # latitude range (°N)
```
The published analysis covers the North Sea, Baltic Sea, and Norwegian Sea.

**Cold spot thresholds** (section: `STEP 2`):
```r
suitability.limit <- 0.2   # maximum mean suitability (0-1 scale)
MPA.limit         <- 7     # minimum distance from MPAs (km)
OWF.limit         <- 7     # minimum distance from OWFs (km)
coast.limit       <- 7     # minimum distance from coastline (km)
```
Cold spots must satisfy all four criteria simultaneously. Increase threshold
values to produce more restrictive (smaller) cold spot areas; decrease them
for more permissive results.

**Figure extent** (section: `STEP 3`) — can be a subset of the study area:
```r
xlim3 <- c(0, 30)
ylim3 <- c(53, 70)
```

**Diagnostic plots:**
```r
plot.data <- TRUE   # set to FALSE to suppress intermediate diagnostic plots
```
When `TRUE`, two diagnostic PNG files are saved during data preparation and
one during cold spot calculation. These are for visual checking only and are
not used in the publication.

---

### Outputs

| File | Description |
|------|-------------|
| `world1geometry.crop.layer.rda` | Cropped country boundaries |
| `shape.owf.crop.layer.rda` | Cropped OWF polygons |
| `coastline.rasterlayer.crop.layer.tif` | Cropped coastline raster |
| `mpa.rasterlayer.crop.layer.tif` | Cropped MPA raster |
| `suitability.rasterlayer.crop.layer.tif` | Cropped suitability raster |
| `mpa.rasterlayer_dist.tif` | Distance from MPAs (m) |
| `owf.rasterlayer_dist.tif` | Distance from OWFs (m) |
| `coast.rasterlayer_dist.tif` | Distance from coastline (m) |
| `Coldspot.layer.rda` | Cold spot multipolygons |
| `MPA.polygon.layer.rda` | MPA polygons for plotting |
| `figure_coldspot_analysis.pdf` | Publication figure |
| `diagnostic_input_layers.png` | Diagnostic: input layers (if `plot.data = TRUE`) |
| `diagnostic_distance_layers.png` | Diagnostic: distance layers (if `plot.data = TRUE`) |
| `diagnostic_coldspot_polygons.png` | Diagnostic: cold spot polygons (if `plot.data = TRUE`) |

> ℹ️ Polygon layers are saved as `.rda` files rather than shapefiles due
> to the complexity of the aggregated multipolygon geometries. Load them
> with `load("Coldspot.layer.rda")` — the object name after loading is
> `unifiedPolygons`.

---

### Runtime

- **Step 1** (data preparation): 10–30 minutes depending on system, dominated
  by distance raster calculation. Subsequent runs are near-instant if
  intermediate files exist.
- **Step 2** (cold spot calculation): 5–15 minutes, dominated by
  polygon aggregation.
- **Step 3** (figure generation): 1–5 minutes.

---

## Author & Contact

**Mats Gunnar Andersson**  
Swedish Veterinary Institute (SVA)  
Email: gunnar.andersson@sva.se  
Date: November 2025  
Last Modified: January 13, 2025


