################################################################################
# Cold Spot Analysis - Cold Spot Calculation Script
################################################################################
# 
# Purpose: Identify priority areas (cold spots) for marine non-indigenous species
#          (NIS) management by integrating multiple spatial criteria.
#
# Cold spot definition:
#   Areas meeting ALL of the following criteria:
#   - High invasion suitability (above threshold)
#   - Sufficient distance from existing MPAs
#   - Sufficient distance from offshore wind farms
#   - Sufficient distance from coastline
#
# Processing workflow:
#   1. Load processed distance rasters and suitability predictions
#   2. Create binary layers based on user-defined thresholds
#   3. Combine criteria using raster multiplication
#   4. Convert to polygon features and aggregate
#   5. Save cold spot polygons and MPA polygons for visualization
#
# Inputs (via command line arguments):
#   - Cropped raster layers from data preparation script
#   - Distance rasters (m) from MPAs, OWFs, and coast
#   - Ensemble suitability predictions (0-1 scale)
#   - User-defined threshold values
#
# Outputs:
#   - Cold spot multipolygon (.rda)
#   - MPA polygon layer for plotting (.rda)
#   - Optional diagnostic plot (.png)
#
# Note: Polygon layers saved as .rda due to compatibility issues with 
#       complex multipolygon shapefiles in sf/terra frameworks.
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
# Parse Command Line Arguments
################################################################################

args <- commandArgs(trailingOnly = TRUE)

# For RStudio debugging: args <- Args2

cat("Received", length(args), "arguments\n")
cat(paste("Argument", seq_along(args), "=", args, collapse = "\n"), "\n\n")

# Input layers
suitability.rasterlayer.crop.layer <- args[1]
mpa.rasterlayer_dist.layer <- args[2]
owf.rasterlayer_dist.layer <- args[3]
coast.rasterlayer_dist.layer <- args[4]

# Layers for plotting
world1geometry.crop.layer <- args[5]
shape.owf.crop.layer <- args[6]
mpa.rasterlayer.crop.layer <- args[7]

# Cold spot criteria thresholds
MPA.range.max <- as.numeric(args[8])      # Max distance for visualization (km)
MPA.limit <- as.numeric(args[9])          # Min distance from MPAs (km)
OWF.range.max <- as.numeric(args[10])     # Max distance for visualization (km)
OWF.limit <- as.numeric(args[11])         # Min distance from OWFs (km)
coast.range.max <- as.numeric(args[12])   # Max distance for visualization (km)
coast.limit <- as.numeric(args[13])       # Min distance from coast (km)
suitability.range.max <- as.numeric(args[14])  # Upper limit for color scale
suitability.limit <- as.numeric(args[15])      # Max suitability threshold

# Options
plot.data <- as.logical(args[16])

# Output files
Coldspot.layer <- args[17]
MPA.polygon.layer <- args[18]

################################################################################
# Load Processed Layers
################################################################################

cat("LOADING PROCESSED LAYERS\n")

cat("Loading country boundaries...\n")
load(world1geometry.crop.layer)
cat("  Loaded:", world1geometry.crop.layer, "\n")

cat("Loading offshore wind farm polygons...\n")
load(shape.owf.crop.layer)
cat("  Loaded:", shape.owf.crop.layer, "\n")

cat("Loading Marine Protected Areas...\n")
mpa.rasterlayer <- raster(mpa.rasterlayer.crop.layer)
cat("  Loaded:", mpa.rasterlayer.crop.layer, "\n")

cat("Loading ensemble suitability predictions...\n")
suitability.rasterlayer <- raster(suitability.rasterlayer.crop.layer)
cat("  Loaded:", suitability.rasterlayer.crop.layer, "\n")

cat("Loading distance rasters...\n")
mpa.rasterlayer_dist <- raster(mpa.rasterlayer_dist.layer)
cat("  MPA distances:", mpa.rasterlayer_dist.layer, "\n")

owf.rasterlayer_dist <- raster(owf.rasterlayer_dist.layer)
cat("  OWF distances:", owf.rasterlayer_dist.layer, "\n")

coast.raster_dist <- raster(coast.rasterlayer_dist.layer)
cat("  Coast distances:", coast.rasterlayer_dist.layer, "\n")

cat("\nAll layers loaded successfully\n\n")

################################################################################
# Apply Threshold Criteria
################################################################################

cat("APPLYING COLD SPOT CRITERIA\n")

cat("Cold spot criteria:\n")
cat("  Suitability: <", suitability.limit, "(low invasion risk)\n")
cat("  Distance from coast: >", coast.limit, "km\n")
cat("  Distance from MPAs: >", MPA.limit, "km\n")
cat("  Distance from OWFs: >", OWF.limit, "km\n\n")

# Convert distances from meters to kilometers
cat("Converting distance units (m → km)...\n")
mpa.rasterlayer_dist.km <- mpa.rasterlayer_dist / 1000
owf.rasterlayer_dist.km <- owf.rasterlayer_dist / 1000
coast.raster_dist.km <- coast.raster_dist / 1000

# Create binary layers based on thresholds
cat("Creating binary criterion layers...\n")
mpa.discrete <- mpa.rasterlayer_dist.km > MPA.limit
cat("  MPA criterion: cells >", MPA.limit, "km from MPAs\n")

owf.discrete <- owf.rasterlayer_dist.km > OWF.limit
cat("  OWF criterion: cells >", OWF.limit, "km from OWFs\n")

suitability.discrete <- suitability.rasterlayer < suitability.limit
cat("  Suitability criterion: cells <", suitability.limit, "\n")

coast.discrete <- coast.raster_dist.km > coast.limit
cat("  Coast criterion: cells >", coast.limit, "km from coast\n")

# Create limited layers for visualization
cat("\nPreparing visualization layers (capped at range maxima)...\n")
mpa.limited <- mpa.rasterlayer_dist.km
mpa.limited[mpa.limited > MPA.range.max] <- MPA.range.max

owf.limited <- owf.rasterlayer_dist.km
owf.limited[owf.limited > OWF.range.max] <- OWF.range.max

suitability.limited <- suitability.rasterlayer
suitability.limited[suitability.limited > suitability.range.max] <- suitability.range.max

coast.limited <- coast.raster_dist.km
coast.limited[coast.limited > coast.range.max] <- coast.range.max

cat("Visualization layers prepared\n\n")

################################################################################
# Identify Cold Spot Areas
################################################################################

cat("IDENTIFYING COLD SPOT LOCATIONS\n")

# Combine all criteria (logical AND operation via multiplication)
cat("Combining criteria layers (logical AND)...\n")
combi.discrete <- mpa.discrete * owf.discrete * coast.discrete * suitability.discrete

# Convert to polygons and aggregate small features
cat("Converting to polygon features...\n")
combi.polygons <- rasterToPolygons(combi.discrete, fun = function(x) {x > 0})

cat("Aggregating adjacent polygons...\n")
unifiedPolygons <- aggregate(combi.polygons)

################################################################################
# Create MPA Polygon Layer for Visualization
################################################################################

cat("Preparing MPA polygons for visualization...\n")
MPAPolygons <- rasterToPolygons(mpa.rasterlayer, fun = function(x) {x > 0})
unifiedMPAPolygons <- aggregate(MPAPolygons)

################################################################################
# Optional: Generate Diagnostic Plot
################################################################################

if (plot.data) {
  cat("Generating diagnostic plot...\n")
  
  png("diagnostic_coldspot_polygons.png", 
      width = 180, height = 180, units = "mm", res = 400)
  
  par(mfrow = c(1, 1))
  
  # Plot cold spots in yellow
  plot(unifiedPolygons, col = "#994F00", border = "#994F00",
       main = "Cold Spot Analysis Results")
  
  # Overlay MPAs in teal
  plot(unifiedMPAPolygons, col = "#40B0A6", border = "#40B0A6", add = TRUE)
  
  # Add country boundaries
  plot(world1geometry, add = TRUE, border = "grey40", lwd = 0.5)
  
  # Add legend
  legend("topright", 
         legend = c("Cold Spots", "Marine Protected Areas", "Land"),
         fill = c("#994F00", "#40B0A6", "grey90"),
         border = c("#994F00", "#40B0A6", "grey40"),
         cex = 0.8)
  
  dev.off()
  
  cat("  Saved: diagnostic_coldspot_polygons.png\n\n")
}

################################################################################
# Save Output Polygon Layers
################################################################################

# Save cold spot polygons
save(unifiedPolygons, file = Coldspot.layer)
cat("Cold spots saved:", Coldspot.layer, "\n")

# Save MPA polygons
save(unifiedMPAPolygons, file = MPA.polygon.layer)
cat("MPA polygons saved:", MPA.polygon.layer, "\n\n")
