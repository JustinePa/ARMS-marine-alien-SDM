################################################################################
# Cold Spot Analysis - Master Script
################################################################################
# 
# Purpose: Orchestrate cold spot identification for marine non-indigenous species
#          management. Executes three sequential subscripts to:
#          1. Prepare spatial data layers
#          2. Calculate cold spot locations
#          3. Generate publication-ready figures
#
# Inputs:
#   - Ensemble suitability predictions (70 NIS species)
#   - Marine Protected Areas (MPAs) 
#   - Offshore Wind Farms (OWFs)
#   - European coastline data
#
# Outputs: 
#   - Processed spatial layers (various formats)
#   - Cold spot polygons (.rda)
#   - Two-panel publication figure (.pdf)
#
# Author: Mats Gunnar Andersson
# Institution: SVA - Swedish Veterinary Institute
# Contact: gunnar.andersson@sva.se
# Date Created: November 2025
# Last Modified: 2025-01-13
################################################################################

library(terra)
library(raster)
library(sf)
library(fBasics)
library(maptools)
library(dplyr)
library(stars)

################################################################################
# CONFIGURATION: Input Data Layers
################################################################################

# Offshore Wind Farms
owf.folder <- "Datalayers"
owf.layer <- "windfarmspolyPolygon.shp"

# Marine Protected Areas
mpa.folder <- "Datalayers"
mpa.rasterlayer <- "wdpa_raster_europe.tif"

# Country boundaries
map.folder <- "Datalayers/ref-countries-2020-01m.shp/CNTR_RG_01M_2020_4326.shp"
map.layer <- "CNTR_RG_01M_2020_4326"

# Ensemble suitability (mean across 70 species, 0-1 scale)
suitability.path <- "Datalayers"
suitability.layer <- "new_stack_mean_norm01_current.tif"

# Coastline reference layer
coastline.path <- "Datalayers"
coastline.layer <- "chl_baseline_2000_2018_depthmean_chl_mean_1.tif"

# Enable diagnostic plots during processing
plot.data <- TRUE

# Define study area extent
xlim <- c(-5, 30)
ylim <- c(50, 70)


################################################################################
# CONFIGURATION: Intermediate Output Files
################################################################################

world1geometry.crop.layer <- "world1geometry.crop.layer.rda"
shape.owf.crop.layer <- "shape.owf.crop.layer.rda"
coastline.rasterlayer.crop.layer <- "coastline.rasterlayer.crop.layer.tif"
mpa.rasterlayer.crop.layer <- "mpa.rasterlayer.crop.layer.tif"
suitability.rasterlayer.crop.layer <- "suitability.rasterlayer.crop.layer.tif"

# Distance rasters
mpa.rasterlayer_dist.layer <- "mpa.rasterlayer_dist.test.tif"
owf.rasterlayer_dist.layer <- "owf.rasterlayer_dist.test.tif"
coast.rasterlayer_dist.layer <- "coast.rasterlayer_dist.test.tif"


################################################################################
# STEP 1: Prepare Spatial Data Layers
################################################################################

cat("STEP 1: Preparing spatial data layers\n")

Args <- c(
  owf.folder, owf.layer,
  mpa.folder, mpa.rasterlayer,
  map.folder, map.layer,
  suitability.path, suitability.layer,
  coastline.path, coastline.layer,
  xlim[1], xlim[2], ylim[1], ylim[2],
  plot.data,
  world1geometry.crop.layer,
  shape.owf.crop.layer,
  coastline.rasterlayer.crop.layer,
  mpa.rasterlayer.crop.layer,
  suitability.rasterlayer.crop.layer,
  mpa.rasterlayer.crop.layer,
  mpa.rasterlayer_dist.layer,
  owf.rasterlayer_dist.layer,
  coast.rasterlayer_dist.layer
)

Mystring <- paste("Rscript cold.spot.prepare.data.R", paste(Args, collapse = " "))
system(Mystring)

cat("\nStep 1 complete\n\n")


################################################################################
# STEP 2: Calculate Cold Spot Locations
################################################################################

cat("STEP 2: Identifying cold spot areas\n")

# Cold spot criteria thresholds
MPA.range.max <- 100        # Maximum distance for visualization (km)
MPA.limit <- 7              # Minimum distance from MPAs (km)

OWF.range.max <- 100
OWF.limit <- 7              # Minimum distance from OWFs (km)

coast.range.max <- 100
coast.limit <- 7            # Minimum distance from coast (km)

suitability.range.max <- 0.6  # Upper limit for color scale (0-1)
suitability.limit <- 0.2      # Minimum suitability threshold

# Output files
Coldspot.layer <- "Coldspot.layer.test.rda"
MPA.polygon.layer <- "MPA.polygon.layer.rda.test"

cat("Thresholds:\n")
cat("  Suitability: >=", suitability.limit, "\n")
cat("  Distance from coast: >=", coast.limit, "km\n")
cat("  Distance from MPAs: >=", MPA.limit, "km\n")
cat("  Distance from OWFs: >=", OWF.limit, "km\n\n")

Args2 <- c(
  suitability.rasterlayer.crop.layer,
  mpa.rasterlayer_dist.layer,
  owf.rasterlayer_dist.layer,
  coast.rasterlayer_dist.layer,
  world1geometry.crop.layer,
  shape.owf.crop.layer,
  mpa.rasterlayer.crop.layer,
  MPA.range.max, MPA.limit,
  OWF.range.max, OWF.limit,
  coast.range.max, coast.limit,
  suitability.range.max, suitability.limit,
  plot.data,
  Coldspot.layer,
  MPA.polygon.layer
)

Mystring <- paste("Rscript cold.spot.calculate.cold.spots.R", paste(Args2, collapse = " "))
system(Mystring)

cat("\nStep 2 complete\n\n")

################################################################################
# STEP 3: Generate Publication Figures
################################################################################

cat("STEP 3: Creating publication-ready figures\n")

# Plot extent (can be subset of full study area)
xlim3 <- c(0, 30)
ylim3 <- c(53, 70)

# Figure specifications for journal submission
plotname <- "figure_coldspot_analysis.pdf"
plotwidth <- 18   # cm (Nature Communications: max 18 cm for 2-column)
plotheight <- 9   # cm
plotres <- 400    # dpi (not used for PDF but kept for PNG option)

cat("Output specifications:\n")
cat("  File:", plotname, "\n")
cat("  Dimensions:", plotwidth, "×", plotheight, "cm\n")
cat("  Extent: Lon", xlim3[1], "to", xlim3[2], "° | Lat", ylim3[1], "to", ylim3[2], "°\n\n")

Args3 <- c(
  suitability.rasterlayer.crop.layer,
  mpa.rasterlayer_dist.layer,
  owf.rasterlayer_dist.layer,
  coast.rasterlayer_dist.layer,
  world1geometry.crop.layer,
  shape.owf.crop.layer,
  mpa.rasterlayer.crop.layer,
  MPA.range.max, MPA.limit,
  OWF.range.max, OWF.limit,
  coast.range.max, coast.limit,
  suitability.range.max, suitability.limit,
  plot.data,
  Coldspot.layer,
  MPA.polygon.layer,
  xlim3[1], xlim3[2],
  ylim3[1], ylim3[2],
  plotname,
  plotwidth, plotheight, plotres
)

Mystring <- paste("Rscript cold.spot.make.plots.R", paste(Args3, collapse = " "))
system(Mystring)

cat("\nStep 3 complete\n\n")

################################################################################
# Analysis Complete
################################################################################
