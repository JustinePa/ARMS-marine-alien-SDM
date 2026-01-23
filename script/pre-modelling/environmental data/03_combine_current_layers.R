################################################################################
# SCRIPT 3: Combine Current Environmental Layers
################################################################################
# 
# Purpose: Load all Bio-ORACLE .nc files, stack them, add distance to coast,
#          and create properly labeled layer names with depth information
#
# Input:   layers2/depthmean/*.nc
#          layers2/depthsurf/*.nc
#          layers2/terrain/*.nc
#          distcoast.tif
# Output:  current_layers_raw.tif
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-065
################################################################################

library(terra)
setwd("")
# Define directory with Bio-ORACLE layers
dir <- "layers"

# Step 1: Load all .nc files
cat("Loading Bio-ORACLE .nc files...\n")
all_files <- list.files(dir, pattern = "\\.nc$", recursive = TRUE, full.names = TRUE)

if (length(all_files) == 0) {
  stop("No .nc files found in ", dir)
}

cat("   Found", length(all_files), "files\n")
cat("     - Depth-mean:", 
    length(list.files(file.path(dir, "depthmean"), pattern = "\\.nc$")), "\n")
cat("     - Depth-surf:", 
    length(list.files(file.path(dir, "depthsurf"), pattern = "\\.nc$")), "\n")
cat("     - Terrain:", 
    length(list.files(file.path(dir, "terrain"), pattern = "\\.nc$")), "\n\n")


# Step 2: Stack all layers
cat("🔗 Stacking all layers...\n")
layers <- rast(all_files)
cat("   Total layers:", nlyr(layers), "\n\n")

# Step 3: Add depth labels to layer names
cat("🏷️  Adding depth labels to layer names...\n")

# Extract folder-based depth labels from file paths
depth_labels <- sapply(dirname(all_files), basename)

# Expand each label to match the number of layers in its file
depth_expanded <- unlist(mapply(function(file, label) {
  rep(label, nlyr(rast(file)))
}, all_files, depth_labels, SIMPLIFY = FALSE))

# Create new names with depth labels appended
new_names <- paste0(names(layers), "_", depth_expanded)
names(layers) <- new_names
print(new_names)

cat("Layer names updated with depth labels\n\n")

# Display first few layer names
cat("Example layer names:\n")
for (i in 1:min(5, nlyr(layers))) {
  cat("     ", i, ". ", names(layers)[i], "\n", sep = "")
}

# Step 4: Load and add distance to coast layer
cat("Loading distance to coast layer...\n")

if (!file.exists("distcoast.tif")) {
  stop("distcoast.tif not found. Please run Script 2 first.")
}

coast_dist <- rast("distcoast.tif")

# Verify spatial alignment
cat("Checking spatial alignment...\n")
if (!compareGeom(layers, coast_dist, stopOnError = FALSE)) {
  cat("Spatial properties don't match, resampling distance layer...\n")
  coast_dist <- resample(coast_dist, layers[[1]], method = "bilinear")
  cat("Resampling complete\n")
} else {
  cat("Spatial properties match\n")
}

# Add distance layer to stack
cat("\n Adding distance layer to stack...\n")
layers_with_dist <- c(layers, coast_dist)
names(layers_with_dist)[nlyr(layers_with_dist)] <- "distance_to_land"

cat("Distance layer added\n")
cat("Total layers:", nlyr(layers_with_dist), "\n\n")

# Step 5: Save combined stack
cat("Saving combined stack...\n")
writeRaster(layers_with_dist, "current_layers_raw.tif", 
            overwrite = TRUE, filetype = "GTiff",
            gdal = c("TILED=YES", "COMPRESS=LZW", "PREDICTOR=2"))

cat(" Saved to: current_layers_raw.tif\n\n")

# Step 6: Summary information
cat("LAYER COMBINATION COMPLETE\n")
cat("Output file: current_layers_raw.tif\n")
cat("Total layers:", nlyr(layers_with_dist), "\n")
cat("Extent:", paste(as.vector(ext(layers_with_dist)), collapse = ", "), "\n")
cat("Resolution:", paste(res(layers_with_dist), collapse = " × "), "\n")
cat("CRS:", crs(layers_with_dist, describe = TRUE)$name, "\n\n")

cat("Layer breakdown:\n")
depth_counts <- table(depth_expanded)
for (depth in names(depth_counts)) {
  cat("   ", depth, ":", depth_counts[depth], "layers\n")
}
cat("Additional: 1 distance_to_land layer\n\n")

cat("Next step: Run Script 04 (focal_interpolation_current.R)\n")
