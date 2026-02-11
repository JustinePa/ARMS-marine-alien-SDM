# Cold Spot Analysis for Ballast Water Contigency Areas

A spatial analysis workflow for identifying areas that can be used as Ballast Water Contigency Areas ("cold spots", i.e. areas with less risks of alien establishment and spread). This analysis integrates species distribution models, marine protected areas, offshore wind farms, and coastal proximity to identify strategic locations.

## Overview

This workflow processes ensemble habitat suitability predictions for 69 marine non-indigenous species across European seas and identifies areas that:
- Low alien suitability
- Are located away from existing Marine Protected Areas (MPAs)
- Are distant from Offshore Wind Farms (OWFs) 
- Are sufficiently far from the coastline

## Author & Contact

**Mats Gunnar Andersson**  
Swedish Veterinary Institute (SVA)  
Email: gunnar.andersson@sva.se  
Date: November 2025  
Last Modified: January 13, 2025

## Workflow Structure

The analysis is organized into a master orchestration script that sequentially executes three processing modules:

```
cold_spot_masterscript.R          # Main orchestration script
├── cold_spot_prepare_data.R      # Step 1: Data preparation
├── cold_spot_calculate_cold_spots.R  # Step 2: Cold spot identification
└── cold_spot_make_plots.R        # Step 3: Figure generation
```

### Step 1: Data Preparation (`cold_spot_prepare_data.R`)

**Purpose:** Prepare and process spatial data layers for analysis

**Inputs:**
- Ensemble suitability predictions (GeoTIFF, 0-1 scale, mean across 69 NIS species)
- Marine Protected Areas database (GeoTIFF raster)
- Offshore Wind Farm polygons (shapefile)
- European country boundaries (shapefile)
- Coastline reference layer (GeoTIFF)
- Study area extent (longitude/latitude bounds)

**Processing:**
1. Loads and crops all spatial layers to study extent
2. Calculates Euclidean distance rasters from:
   - Marine Protected Areas
   - Offshore Wind Farms
   - Coastline
3. Saves processed layers with file checksums to avoid redundant computation

**Outputs:**
- Cropped spatial layers (.tif, .rda files)
- Distance rasters (.tif files, units: meters)
- Optional diagnostic plots (.png)

**Key Features:**
- Smart caching: checks for existing outputs to avoid re-computation
- Distance calculations use `terra::distance()` for computational efficiency
- Diagnostic plotting available for quality control

### Step 2: Cold Spot Calculation (`cold_spot_calculate_cold_spots.R`)

**Purpose:** Identify areas meeting all cold spot criteria

**Cold Spot Definition:**  
Areas are classified as cold spots when they meet ALL of the following criteria:
- **Low cummulative alien suitability:** Above user-defined threshold (default: ≤ 0.2)
- **Minimum distance from MPAs:** Greater than threshold (default: ≥ 7 km)
- **Minimum distance from OWFs:** Greater than threshold (default: ≥ 7 km)
- **Minimum distance from coast:** Greater than threshold (default: ≥ 7 km)

**Processing Workflow:**
1. Loads processed distance rasters and suitability predictions
2. Converts distances from meters to kilometers
3. Creates binary criterion layers based on thresholds
4. Combines criteria using logical AND operation (raster multiplication)
5. Converts resulting raster to polygon features
6. Aggregates adjacent polygons into unified features

**Outputs:**
- Cold spot multipolygon layer (.rda)
- MPA polygon layer for visualization (.rda)
- Optional diagnostic plot showing cold spots and MPAs (.png)

**Note:** Polygon layers are saved as `.rda` files due to compatibility issues with complex multipolygon shapefiles in the sf/terra framework.

### Step 3: Figure Generation (`cold_spot_make_plots.R`)

**Purpose:** Create publication-ready two-panel figure

**Figure Design:**

**Panel A (left):** Suitability map with infrastructure overlay
- Continuous suitability gradient (0-1 scale, 10 color bins)
- Marine Protected Areas overlay
- Offshore Wind Farms overlay
- Identified cold spots overlay
- Comprehensive horizontal legend with all categories

**Panel B (right):** Cold spot focus map
- Model extent (areas with suitability predictions)
- Cold spot polygons highlighted
- Simplified visualization for clarity

**Outputs:**
- Two-panel publication figure (PDF, vector format)
- Alternative PNG output available (modify script for raster format)

### Required Data Layers

All input data should be stored in a `Datalayers/` directory:

1. **Ensemble Suitability** (`new_stack_mean_norm01_current.tif`)
   - Format: GeoTIFF raster
   - Values: 0-1 (mean habitat suitability across 70 NIS species)
   - CRS: WGS 84 (EPSG:4326)
   - Resolution: Should match your study requirements (e.g., 0.083°)

2. **Marine Protected Areas** (`wdpa_raster_europe.tif`)
   - Format: GeoTIFF raster
   - Values: Binary (1 = MPA, NA = non-MPA)
   - Source: World Database on Protected Areas (WDPA)

3. **Offshore Wind Farms** (`windfarmspolyPolygon.shp`)
   - Format: Polygon shapefile
   - Required files: .shp, .shx, .dbf, .prj

4. **Country Boundaries** (`CNTR_RG_01M_2020_4326.shp`)
   - Format: Polygon shapefile
   - Source: EuroGeographics or equivalent
   - CRS: WGS 84 (EPSG:4326)

5. **Coastline Reference** (`chl_baseline_2000_2018_depthmean_chl_mean_1.tif`)
   - Format: GeoTIFF raster
   - Purpose: Defines ocean mask for study area
   - Note: Any ocean raster can serve this purpose

### Expected Data Structure

```
project_directory/
├── cold_spot_masterscript.R
├── cold_spot_prepare_data.R
├── cold_spot_calculate_cold_spots.R
├── cold_spot_make_plots.R
└── Datalayers/
    ├── new_stack_mean_norm01_current.tif
    ├── wdpa_raster_europe.tif
    ├── windfarmspolyPolygon.shp
    ├── chl_baseline_2000_2018_depthmean_chl_mean_1.tif
    └── ref-countries-2020-01m.shp/
        └── CNTR_RG_01M_2020_4326.shp
```

### R Version
Tested with R version 4.0.0 or higher

The master script will automatically:
1. Execute all three processing steps in sequence
2. Display progress messages in the console
3. Generate intermediate files and final outputs
4. Report completion status for each step

## Output Files

### Intermediate Files (Cached)

Created in Step 1 (data preparation):

```
world1geometry.crop.layer.rda              # Cropped country boundaries
shape.owf.crop.layer.rda                   # Cropped OWF polygons
coastline.rasterlayer.crop.layer.tif       # Cropped coastline raster
mpa.rasterlayer.crop.layer.tif             # Cropped MPA raster
suitability.rasterlayer.crop.layer.tif     # Cropped suitability raster
mpa.rasterlayer_dist.test.tif              # Distance from MPAs (m)
owf.rasterlayer_dist.test.tif              # Distance from OWFs (m)
coast.rasterlayer_dist.test.tif            # Distance from coast (m)
```

Created in Step 2 (cold spot calculation):

```
Coldspot.layer.test.rda                    # Cold spot polygons
MPA.polygon.layer.rda.test                 # MPA polygons for plotting
```

### Final Outputs

```
figure_coldspot_analysis.pdf               # Two-panel publication figure
```
