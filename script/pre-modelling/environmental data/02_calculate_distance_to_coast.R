################################################################################
# Calculate Distance to Coast from Bathymetry Layer
################################################################################
# 
# Purpose: Create a distance-to-coast layer to add to environmental stacks
#          For each ocean cell, calculate distance to nearest land/coast
#
# Input:   base.tif - Bathymetry layer from Bio-ORACLE
#          (Ocean cells = data values, Land cells = NA)
#
# Output:  distcoast.tif - Distance to coast in kilometers
#
# Method:  Uses aggregation to speed up distance calculation,
#          then disaggregates back to original resolution
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(terra)

setwd("")

# Load bathymetry layer
base <- rast("base.tif") # extracted from Bio-ORACLE terrain layer and renamed

# Step 1: Create ocean mask
# Ocean cells where bathymetry exists (non-NA) = 1
# Land cells where bathymetry is NA remain NA
ocean_mask <- base
ocean_mask[] <- NA  # Start with all NA
ocean_mask <- mask(ocean_mask, base, updatevalue = 1)  # Set ocean cells to 1

# Check the mask
cat("Ocean mask created\n")

# Step 2: Aggregate to speed up distance calculation
# Aggregating by factor 4 reduces computation time ~16x
# (4x4 = 16 cells become 1 cell)
cat("Aggregating by factor 4 to speed up calculation...\n")
ocean_mask_agg <- aggregate(ocean_mask, fact = 4, fun = "mean", na.rm = TRUE)

# Step 3: Calculate distance to coast
# terra::distance() calculates distance from non-NA cells to nearest NA cell
# Since ocean = 1 and land = NA, this gives distance TO COAST for each ocean cell
cat("Calculating distance to coast...\n")
coast_dist_agg <- terra::distance(ocean_mask_agg)

# Step 4: Disaggregate back to original resolution
cat("Disaggregating back to original resolution...\n")
coast_dist <- disagg(coast_dist_agg, fact = 4)

# Step 5: Mask to original ocean extent
# Ensure distance layer only covers ocean cells
coast_dist <- mask(coast_dist, base)

# Step 6: Convert from meters to kilometers
coast_dist <- coast_dist / 1000

# Step 7: Set layer name
names(coast_dist) <- "coastdist"

# Save output
cat("Saving to distcoast.tif...\n")
writeRaster(coast_dist, "distcoast.tif", overwrite = TRUE)

cat("✅ Distance to coast layer created successfully!\n")

# Optional: Create a quick plot
if (interactive()) {
  plot(coast_dist, main = "Distance to Coast (km)")
}

cat("Next step: Run Script 03 (combine_current_layers.R)\n")
