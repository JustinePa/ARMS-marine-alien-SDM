################################################################################
# Cold Spot Analysis - cold.spot.prepare.data.R
################################################################################
# 
# Purpose: Prepare and process spatial data layers for cold spot identification.
#          Crops layers to study area, calculates distance rasters, and saves
#          intermediate outputs to reduce computational time in subsequent steps.
#
# Processing steps:
#   1. Load and crop raw data layers to study extent
#   2. Calculate Euclidean distance rasters from:
#      - Marine Protected Areas (MPAs)
#      - Offshore Wind Farms (OWFs)  
#      - Coastline
#   3. Save processed layers with checksums to avoid redundant computation
#
# Inputs (via command line arguments):
#   - Raw suitability raster (ensemble predictions, 70 NIS)
#   - MPA database raster
#   - OWF polygon shapefile
#   - Country boundary shapefile
#   - Coastline reference raster
#   - Study area extent (xlim, ylim)
#
# Outputs:
#   - Cropped spatial layers (.tif, .rda)
#   - Distance rasters (.tif)
#   - Optional diagnostic plots (.png)
#
# Note: Script checks for existing outputs to avoid re-computation. To force
#       recalculation, delete existing files or change output filenames in
#       the master script.
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

# Disable spherical geometry for compatibility with legacy data
sf_use_s2(FALSE)

################################################################################
# Parse Command Line Arguments
################################################################################

args <- commandArgs(trailingOnly = TRUE)

# For RStudio debugging: args <- Args

cat("Received", length(args), "arguments\n")
if (length(args) < 24) stop("Expected 24 arguments, received ", length(args))
cat(paste("Argument", seq_along(args), "=", args, collapse = "\n"), "\n\n")

# Input data paths
owf.folder <- args[1]
owf.layer <- args[2]
mpa.folder <- args[3]
mpa.layer <- args[4]
map.folder <- args[5]
map.layer <- args[6]
suitability.path <- args[7]
suitability.layer <- args[8]
coastline.path <- args[9]
coastline.layer <- args[10]

# Study area extent
xlim <- as.numeric(c(args[11], args[12]))
ylim <- as.numeric(c(args[13], args[14]))

# Diagnostic plotting flag
plot.data <- as.logical(args[15])

# Output filenames for cropped layers
world1geometry.crop.layer <- args[16]
shape.owf.crop.layer <- args[17]
coastline.rasterlayer.crop.layer <- args[18]
mpa.rasterlayer.crop.layer <- args[19]
suitability.rasterlayer.crop.layer <- args[20]
# Note: args[21] duplicates args[19] (legacy)

# Output filenames for distance rasters
mpa.rasterlayer_dist.layer <- args[22]
owf.rasterlayer_dist.layer <- args[23]
coast.rasterlayer_dist.layer <- args[24]


################################################################################
# Load Raw Data Layers
################################################################################

cat("LOADING RAW DATA LAYERS\n")

cat("Reading coastline reference...\n")
coastline.rasterlayer <- raster(paste(coastline.path, coastline.layer, sep = "/"))

cat("Reading Marine Protected Areas...\n")
mpa.rasterlayer <- raster(paste(mpa.folder, mpa.layer, sep = "/"))

cat("Reading ensemble suitability (70 NIS species)...\n")
suitability.rasterlayer <- raster(paste(suitability.path, suitability.layer, sep = "/"))

cat("Reading Offshore Wind Farms...\n")
shape.owf <- st_read(paste(owf.folder, "/", owf.layer, sep = ""))
shape.owf <- shape.owf %>% st_set_crs(4979)  # WGS 84

cat("Reading country boundaries...\n")
shape.world <- st_read(map.folder, layer = map.layer)$geometry

cat("\nAll layers loaded successfully\n\n")

################################################################################
# Define Study Area Extent and Cropping Mask
################################################################################

cat("DEFINING STUDY AREA\n")

cat("Longitude range:", xlim[1], "to", xlim[2], "°E\n")
cat("Latitude range:", ylim[1], "to", ylim[2], "°N\n\n")

# Create extent object
e <- extent(c(xlim, ylim))

# Create mask from coastline layer
fullraster <- coastline.rasterlayer
crop.coastline <- crop(fullraster, e)
mask <- crop.coastline
mask[!is.na(mask)] <- 1

################################################################################
# Crop Layers to Study Extent
################################################################################

cat("CROPPING LAYERS TO STUDY EXTENT\n")

# Country boundaries
if (!file.exists(world1geometry.crop.layer)) {
  cat("Processing country boundaries...\n")
  
  world1geometry.sf <- sf::st_as_sf(shape.world)
  
  mask_bbox <- st_bbox(
    c(xmin = xlim[1], xmax = xlim[2], 
      ymin = ylim[1], ymax = ylim[2]), 
    crs = st_crs(world1geometry.sf)
  )
  
  world1geometry <- st_crop(world1geometry.sf, mask_bbox)
  save(world1geometry, file = world1geometry.crop.layer)
  cat("  Saved:", world1geometry.crop.layer, "\n")
} else {
  load(world1geometry.crop.layer)
  cat("  Using existing:", world1geometry.crop.layer, "\n")
}

# Offshore Wind Farms
if (!file.exists(shape.owf.crop.layer)) {
  cat("Processing offshore wind farms...\n")
  
  mask_bbox <- st_bbox(
    c(xmin = xlim[1], xmax = xlim[2], 
      ymin = ylim[1], ymax = ylim[2]), 
    crs = st_crs(shape.owf)
  )
  
  shape.owf <- st_crop(shape.owf, mask_bbox)
  save(shape.owf, file = shape.owf.crop.layer)
  cat("  Saved:", shape.owf.crop.layer, "\n")
} else {
  load(shape.owf.crop.layer)
  cat("  Using existing:", shape.owf.crop.layer, "\n")
}

# Coastline raster
if (!file.exists(coastline.rasterlayer.crop.layer)) {
  cat("Processing coastline layer...\n")
  
  coastline.rasterlayer <- crop(coastline.rasterlayer, e)
  writeRaster(coastline.rasterlayer, coastline.rasterlayer.crop.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", coastline.rasterlayer.crop.layer, "\n")
} else {
  coastline.rasterlayer <- raster(coastline.rasterlayer.crop.layer)
  cat("  Using existing:", coastline.rasterlayer.crop.layer, "\n")
}

# Marine Protected Areas
if (!file.exists(mpa.rasterlayer.crop.layer)) {
  cat("Processing MPA layer...\n")
  
  mpa.rasterlayer <- crop(mpa.rasterlayer, e)
  writeRaster(mpa.rasterlayer, mpa.rasterlayer.crop.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", mpa.rasterlayer.crop.layer, "\n")
} else {
  mpa.rasterlayer <- raster(mpa.rasterlayer.crop.layer)
  cat("  Using existing:", mpa.rasterlayer.crop.layer, "\n")
}

# Ensemble suitability
if (!file.exists(suitability.rasterlayer.crop.layer)) {
  cat("Processing suitability layer...\n")
  
  suitability.rasterlayer <- crop(suitability.rasterlayer, e)
  writeRaster(suitability.rasterlayer, suitability.rasterlayer.crop.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", suitability.rasterlayer.crop.layer, "\n")
} else {
  suitability.rasterlayer <- raster(suitability.rasterlayer.crop.layer)
  cat("  Using existing:", suitability.rasterlayer.crop.layer, "\n")
}

cat("\nCropping complete\n\n")

################################################################################
# Optional: Plot Input Layers
################################################################################

if (plot.data) {
  cat("Generating diagnostic plot of input layers...\n")
  
  png("diagnostic_input_layers.png", 
      width = 3 * 180, height = 2 * 180, units = "mm", res = 400)
  
  par(mfrow = c(2, 3))
  par(mar = c(1, 1, 4, 2))
  
  plot(mpa.rasterlayer, xlim = xlim, ylim = ylim, main = "Marine Protected Areas")
  plot(suitability.rasterlayer, xlim = xlim, ylim = ylim, main = "Ensemble Suitability")
  plot(shape.owf, xlim = xlim, ylim = ylim, main = "Offshore Wind Farms")
  plot(world1geometry, xlim = xlim, ylim = ylim, main = "Country Boundaries")
  plot(coastline.rasterlayer, xlim = xlim, ylim = ylim, main = "Coastline Reference")
  
  dev.off()
  cat("  Saved: diagnostic_input_layers.png\n\n")
}

################################################################################
# Calculate Distance Rasters
################################################################################

cat("CALCULATING EUCLIDEAN DISTANCE RASTERS\n")

# Distance from Marine Protected Areas
if (!file.exists(mpa.rasterlayer_dist.layer)) {
  cat("Computing distance from MPAs (this may take several minutes)...\n")
  
  mpa.rasterlayer[!is.na(mpa.rasterlayer)] <- 0
  mpa.rasterlayer_dist <- terra::distance(mpa.rasterlayer)
  mpa.rasterlayer_dist <- mpa.rasterlayer_dist * mask
  
  writeRaster(mpa.rasterlayer_dist, mpa.rasterlayer_dist.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", mpa.rasterlayer_dist.layer, "\n")
} else {
  mpa.rasterlayer_dist <- raster(mpa.rasterlayer_dist.layer)
  cat("  Using existing:", mpa.rasterlayer_dist.layer, "\n")
}

# Distance from Offshore Wind Farms
if (!file.exists(owf.rasterlayer_dist.layer)) {
  cat("Computing distance from OWFs...\n")
  
  cropraster <- mask
  cropraster[] <- 0
  OWF.raster <- rasterize(shape.owf, cropraster)
  OWF.raster[!is.na(OWF.raster)] <- 0
  
  owf.rasterlayer_dist <- terra::distance(OWF.raster)
  owf.rasterlayer_dist <- owf.rasterlayer_dist * mask
  
  writeRaster(owf.rasterlayer_dist, owf.rasterlayer_dist.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", owf.rasterlayer_dist.layer, "\n")
} else {
  owf.rasterlayer_dist <- raster(owf.rasterlayer_dist.layer)
  cat("  Using existing:", owf.rasterlayer_dist.layer, "\n")
}

# Distance from coastline
if (!file.exists(coast.rasterlayer_dist.layer)) {
  cat("Computing distance from coast...\n")
  
  coast.raster <- mask
  coast.raster[!is.na(mask)] <- NA
  coast.raster[is.na(mask)] <- 0
  # Distance from coast = distance from land pixels into the ocean
  # Land cells set to 0 (source), ocean cells set to NA (target)
  
  coast.raster_dist <- terra::distance(coast.raster)
  coast.raster_dist <- coast.raster_dist * mask
  
  writeRaster(coast.raster_dist, coast.rasterlayer_dist.layer, 
              format = "GTiff", overwrite = TRUE)
  cat("  Saved:", coast.rasterlayer_dist.layer, "\n")
} else {
  coast.raster_dist <- raster(coast.rasterlayer_dist.layer)
  cat("  Using existing:", coast.rasterlayer_dist.layer, "\n")
}

cat("\nDistance calculations complete\n\n")

################################################################################
# Optional: Plot Calculated Distance Layers
################################################################################

if (plot.data) {
  cat("Generating diagnostic plot of distance layers...\n")
  
  png("diagnostic_distance_layers.png", 
      width = 3 * 180, height = 2 * 180, units = "mm", res = 400)
  
  par(mfrow = c(3, 2))
  par(mar = c(1, 1, 4, 2))
  
  plot(mpa.rasterlayer, xlim = xlim, ylim = ylim, main = "MPA Locations")
  plot(mpa.rasterlayer_dist, xlim = xlim, ylim = ylim, main = "Distance from MPAs")
  
  plot(shape.owf, xlim = xlim, ylim = ylim, main = "OWF Locations")
  plot(owf.rasterlayer_dist, xlim = xlim, ylim = ylim, main = "Distance from OWFs")
  
  plot(coast.raster_dist, xlim = xlim, ylim = ylim, main = "Distance from Coast")
  plot(suitability.rasterlayer, xlim = xlim, ylim = ylim, main = "Ensemble Suitability")
  
  dev.off()
  cat("  Saved: diagnostic_distance_layers.png\n\n")
}
