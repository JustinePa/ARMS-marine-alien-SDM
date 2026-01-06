################################################################################
# SCRIPT 4: Focal Interpolation for Current Environmental Layers
################################################################################
# 
# Purpose: Fill coastal gaps in Bio-ORACLE layers using 3×3 focal mean
#          Many occurrence records are near coasts where satellite/model data
#          has edge artifacts or missing values
#
# Input:   current_layers_raw.tif (from Script 3)
# Output:  current_layers_interpolated.tif
#
# Method:  For each NA cell, replace with mean of 8 neighbors
#          Keep original values for non-NA cells
#          Apply only to ocean (land remains NA)
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2025-01-06
################################################################################

library(terra)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)

cat("FOCAL INTERPOLATION - Filling Coastal Gaps\n")

setwd("C:/biomod2_git/test")

# Load the stack to interpolate
cat("Loading environmental layers...\n")
layers <- rast("current_layers_raw.tif")
cat("   Layers:", nlyr(layers), "\n")
cat("   Resolution:", paste(res(layers), collapse = " × "), "\n\n")

# Use the first layer as template for masking
template <- layers[[1]]

# Load and prepare land mask
cat(" Creating land mask from Natural Earth data...\n")
land <- ne_countries(scale = "medium", returnclass = "sf")
land <- st_transform(land, crs(template))
land_vect <- vect(land)

# Rasterize land polygons (land = 1, ocean = NA)
land_mask <- rasterize(land_vect, template, field = 1, background = NA)
land_mask[!is.na(land_mask)] <- 1

cat("   Land cells:", sum(values(land_mask) == 1, na.rm = TRUE), "\n")
cat("   Ocean cells:", sum(is.na(values(land_mask))), "\n\n")

# Step 1: Mask layers to remove land values
cat("Step 1/3: Masking land cells...\n")
masked_list <- lapply(1:nlyr(layers), function(i) {
  if (i %% 5 == 0) cat("   Processing layer", i, "of", nlyr(layers), "\n")
  this_layer <- layers[[i]]
  mask(this_layer, land_mask, maskvalue = 1)
})

masked_layers <- rast(masked_list)
cat("Masking complete\n\n")

# Save intermediate result (optional)
cat("Saving masked layers (optional checkpoint)...\n")
saveRDS(masked_layers, "masked_layers_current.rds")
cat("Saved to: masked_layers_current.rds\n\n")

# Step 2: Apply focal interpolation
cat("Step 2/3: Applying focal interpolation...\n")
cat("   Method: 3×3 window, replace NA with neighbor mean\n")
cat("   This may take 15-30 minutes...\n\n")

filled_list <- lapply(1:nlyr(masked_layers), function(i) {
  cat("   [", i, "/", nlyr(masked_layers), "] ", names(masked_layers)[i], "\n", sep = "")
  
  this_layer <- masked_layers[[i]]
  
  # Focal operation: if center is NA, use mean of neighbors
  focal(this_layer, w = 3, fun = function(x) {
    if (is.na(x[5])) {  # x[5] is the center cell
      mean(x, na.rm = TRUE)
    } else {
      x[5]  # Keep original value
    }
  })
})

filled_layers <- rast(filled_list)
cat("\n  Focal interpolation complete\n\n")

# Step 3: Quality control
cat(" Step 3/3: Quality control checks...\n")

# Check that we didn't accidentally interpolate onto land
test_layer_before <- masked_layers[[1]]
test_layer_after <- filled_layers[[1]]

na_before <- sum(is.na(values(test_layer_before)))
na_after <- sum(is.na(values(test_layer_after)))

cat("   NA cells before interpolation:", na_before, "\n")
cat("   NA cells after interpolation:", na_after, "\n")
cat("   Cells filled:", na_before - na_after, "\n\n")

# Visual check
if (interactive()) {
  cat("Generating comparison plots...\n")
  par(mfrow = c(1, 3))
  plot(land_mask, main = "Land Mask\n(1 = Land, NA = Ocean)")
  plot(test_layer_before, main = "Before Interpolation\n(Coastal gaps visible)")
  plot(test_layer_after, main = "After Interpolation\n(Gaps filled)")
  par(mfrow = c(1, 1))
}

# Save final output
cat("\n Saving interpolated layers...\n")
writeRaster(filled_layers, "current_layers_interpolated.tif", 
            overwrite = TRUE, filetype = "GTiff",
            gdal = c("TILED=YES", "COMPRESS=LZW", "PREDICTOR=2"))

# Also save as RDS for R-specific use
saveRDS(filled_layers, "filled_layers_current.rds")

cat(" Saved to: current_layers_interpolated.tif\n")
cat(" Saved to: filled_layers_current.rds\n\n")

# Summary statistics
cat("FOCAL INTERPOLATION COMPLETE\n")
cat("Input:  current_layers_raw.tif\n")
cat("Output: current_layers_interpolated.tif\n")
cat("Layers:", nlyr(filled_layers), "\n")
cat("Method: 3×3 focal mean for coastal gap-filling\n\n")
cat("Next step: Run Script 05 (vif_analysis.R)\n")
