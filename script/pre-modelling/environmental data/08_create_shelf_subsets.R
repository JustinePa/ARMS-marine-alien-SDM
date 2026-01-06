################################################################################
# SCRIPT 8: Create Continental Shelf Subsets
################################################################################
# 
# Purpose: Mask environmental layers to continental shelf only
#          Continental shelf = bathymetry ≥ -200m (0 to -200m depth)
#
# Input:   myExpl_final.tif
#          ssp126_layers_final_2100.tif
#          ssp245_layers_final_2100.tif
#          ssp585_layers_final_2100.tif

# Output:  myExpl_shelf.tif
#          ssp126_shelf_2100.tif
#          ssp245_shelf_2100.tif
#          ssp585_shelf_2100.tif
#
# Rationale: Many marine invasive species are restricted to continental shelf
#            habitats due to proximity to ports, suitable depth, and coastal
#            environmental conditions
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2025-01-06
################################################################################

library(terra)

cat("CREATING CONTINENTAL SHELF SUBSETS\n")

setwd("C:/biomod2_git/test")

# Define continental shelf depth threshold
depth_thresh <- -200  # 0 to -200m depth

cat("Configuration:\n")
cat("   Continental shelf definition: 0 to", depth_thresh, "m depth\n")
cat("   Bathymetry layer name: bathymetry_mean_terrain\n\n")

# Files to process
files_to_process <- list(
  current = list(
    input = "myExpl_final.tif",
    output = "myExpl_shelf.tif",
    description = "Current conditions"
  ),
  ssp126 = list(
    input = "ssp126_layers_final_2100.tif",
    output = "ssp126_shelf_2100.tif",
    description = "SSP 1-2.6 (2100)"
  ),
  ssp245 = list(
    input = "ssp245_layers_final_2100.tif",
    output = "ssp245_shelf_2100.tif",
    description = "SSP 2-4.5 (2100)"
  ),
  ssp585 = list(
    input = "ssp585_layers_final_2100.tif",
    output = "ssp585_shelf_2100.tif",
    description = "SSP 5-8.5 (2100)"
  )
)

# Process each stack
for (scenario in names(files_to_process)) {
  info <- files_to_process[[scenario]]
  
  cat("│ Processing:", info$description, rep(" ", 35 - nchar(info$description)), "│\n")
  
  # Check if input file exists
  if (!file.exists(info$input)) {
    cat("Input file not found:", info$input, "\n")
    cat("   Skipping...\n\n")
    next
  }
  
  # Load stack
  cat("Loading:", info$input, "\n")
  myExpl <- rast(info$input)
  cat("      Layers:", nlyr(myExpl), "\n")
  
  # Check for bathymetry layer
  bathy_name <- "bathymetry_mean_terrain"
  if (!bathy_name %in% names(myExpl)) {
    cat("Bathymetry layer not found in stack\n")
    cat("      Available layers:", paste(names(myExpl), collapse = ", "), "\n\n")
    next
  }
  
  # Extract bathymetry layer
  bathy <- myExpl[[bathy_name]]
  
  # Create shelf mask
  cat("Creating continental shelf mask...\n")
  cat("      Threshold:", depth_thresh, "m\n")
  
  # Shelf mask: TRUE where depth >= -200m (shallower than 200m)
  shelf_mask <- bathy >= depth_thresh
  
  # Count cells
  total_ocean <- sum(!is.na(values(bathy)))
  shelf_cells <- sum(values(shelf_mask), na.rm = TRUE)
  shelf_percent <- round(shelf_cells / total_ocean * 100, 1)
  
  cat("      Total ocean cells:", total_ocean, "\n")
  cat("      Shelf cells:", shelf_cells, "(", shelf_percent, "%)\n")
  
  # Apply mask to all layers
  cat("Applying shelf mask to all layers...\n")
  myExpl_shelf <- mask(myExpl, shelf_mask, maskvalues = 0)
  
  # Save output
  cat("Saving:", info$output, "\n")
  writeRaster(myExpl_shelf, info$output, overwrite = TRUE,
              filetype = "GTiff", gdal = c("TILED=YES", "COMPRESS=LZW", "PREDICTOR=2"))
  
  cat("Complete\n\n")
}

# Summary
cat("CONTINENTAL SHELF SUBSETS CREATED\n")

cat("Output files:\n")
for (scenario in names(files_to_process)) {
  info <- files_to_process[[scenario]]
  if (file.exists(info$output)) {
    cat("✓", info$output, "\n")
  } else {
    cat("X", info$output, "(not created)\n")
  }
}

cat("\n Shelf definition:\n")
cat("   Depth range: 0 to", depth_thresh, "m\n")
cat("   Includes: Coastal and shallow water habitats\n")
cat("   Excludes: Deep ocean (>", abs(depth_thresh), "m depth)\n\n")
