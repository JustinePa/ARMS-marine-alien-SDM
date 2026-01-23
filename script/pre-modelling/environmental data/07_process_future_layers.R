################################################################################
# SCRIPT 7: Process Future Environmental Layers
################################################################################
# 
# Purpose: Stack future Bio-ORACLE layers, filter to VIF-selected variables,
#          apply focal interpolation, then add static layers from current
#
# Input:   layers_future/ssp[126|245|585]_2100/*.nc (all downloaded variables)
#          myExpl_final.tif (for static layers: bathymetry, distance)
#          selected_var_names.txt (for filtering)
# Output:  ssp126_layers_final_2100.tif
#          ssp245_layers_final_2100.tif
#          ssp585_layers_final_2100.tif
#
# Strategy: Filter to VIF-selected vars BEFORE interpolation (saves time!)
# Note:    Bathymetry and distance are static (don't change with climate),
#          so we reuse the interpolated versions from current conditions
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(terra)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)

cat("PROCESSING FUTURE ENVIRONMENTAL LAYERS\n")

setwd("C:/biomod2_git/test")

# Configuration
future_dir <- "layers_future"
ssp_scenarios <- c("ssp126", "ssp245", "ssp585")
year <- "2100"

# Load VIF-selected variables
cat(" Loading VIF-selected variables...\n")
selected_var_names <- readLines("selected_var_names.txt")
cat("   Variables:", length(selected_var_names), "\n\n")

# Separate static vs climate variables
static_vars <- c("bathymetry_mean_terrain", "distance_to_land")
climate_vars <- setdiff(selected_var_names, static_vars)
cat("   Climate variables:", length(climate_vars), "\n")
cat("   Static variables:", length(static_vars), "(from myExpl_final.tif)\n\n")

# Load static layers from current conditions
cat(" Loading static layers from current conditions...\n")
if (!file.exists("myExpl_final.tif")) {
  stop("myExpl_final.tif not found. Please run Scripts 1-5 first.")
}

current_final <- rast("myExpl_final.tif")
static_layers <- subset(current_final, static_vars)
cat("Extracted:", paste(names(static_layers), collapse = ", "), "\n\n")

# Create land mask for interpolation
cat("Creating land mask...\n")
template <- static_layers[[1]]
land <- ne_countries(scale = "medium", returnclass = "sf")
land <- st_transform(land, crs(template))
land_vect <- vect(land)
land_mask <- rasterize(land_vect, template, field = 1, background = NA)
land_mask[!is.na(land_mask)] <- 1
cat("Land mask created\n\n")

# Define focal interpolation function
fill_coastal_gaps <- function(layer) {
  focal(layer, w = 3, fun = function(x) {
    if (is.na(x[5])) {
      mean(x, na.rm = TRUE)
    } else {
      x[5]
    }
  })
}

# Process each SSP scenario
for (ssp in ssp_scenarios) {
  cat("\n╔═══════════════════════════════════════════════════╗\n")
  cat("║  Processing scenario:", ssp, "                        \n")
  cat("╚═══════════════════════════════════════════════════╝\n\n")
  
  ssp_year <- paste0(ssp, "_", year)
  ssp_dir <- file.path(future_dir, ssp_year)
  
  # Step 1: Load all downloaded climate layers
  cat("Step 1/5: Loading climate layers...\n")
  
  all_files <- list.files(ssp_dir, pattern = "\\.nc$", 
                          full.names = TRUE, recursive = TRUE)
  
  if (length(all_files) == 0) {
    cat("No files found for", ssp, "\n")
    next
  }
  
  layers <- rast(all_files)
  cat("   Loaded:", nlyr(layers), "layers (all downloaded)\n\n")
  
  # Step 2: Add depth labels
  cat("Step 2/5: Adding depth labels...\n")
  depth_labels <- sapply(dirname(all_files), basename)
  depth_expanded <- unlist(mapply(function(file, label) {
    rep(label, nlyr(rast(file)))
  }, all_files, depth_labels, SIMPLIFY = FALSE))
  
  new_names <- paste0(names(layers), "_", depth_expanded)
  names(layers) <- new_names
  cat("Labels added\n\n")
  
  # Step 3: Filter to VIF-selected climate variables BEFORE interpolation
  cat("Step 3/5: Filtering to VIF-selected climate variables...\n")
  cat("   (Saves interpolation time by processing only needed layers)\n")
  
  available_vars <- names(layers)
  vars_to_keep <- intersect(climate_vars, available_vars)
  vars_removed <- setdiff(available_vars, vars_to_keep)
  
  cat("   Available:", length(available_vars), "layers\n")
  cat("   Keeping:", length(vars_to_keep), "VIF-selected\n")
  cat("   Removing:", length(vars_removed), "not selected\n")
  
  if (length(vars_removed) > 0) {
    cat("   Examples removed:", paste(head(vars_removed, 3), collapse = ", "), "\n")
  }
  
  layers_filtered <- subset(layers, vars_to_keep)
  cat(" Filtered to VIF-selected variables\n\n")
  
  # Step 4: Focal interpolation (only on VIF-selected layers!)
  cat("Step 4/5: Applying focal interpolation...\n")
  cat("   Processing", nlyr(layers_filtered), "layers\n")
  cat("   (Faster than interpolating all", nlyr(layers), "!)\n\n")
  
  # Mask land
  masked_list <- lapply(1:nlyr(layers_filtered), function(i) {
    if (i %% 5 == 0) cat("   Masking layer", i, "of", nlyr(layers_filtered), "\n")
    mask(layers_filtered[[i]], land_mask, maskvalue = 1)
  })
  masked_layers <- rast(masked_list)
  
  # Apply focal fill
  cat("\n   Interpolating coastal gaps...\n")
  filled_list <- lapply(1:nlyr(masked_layers), function(i) {
    if (i %% 5 == 0) cat("   Filling layer", i, "of", nlyr(masked_layers), "\n")
    fill_coastal_gaps(masked_layers[[i]])
  })
  filled_layers <- rast(filled_list)
  cat("\n Interpolation complete\n\n")
  
  # Step 5: Add static layers from current conditions
  cat("Step 5/5: Adding static layers...\n")
  
  # Ensure alignment
  if (!compareGeom(filled_layers, static_layers, stopOnError = FALSE)) {
    cat("Resampling static layers...\n")
    static_aligned <- resample(static_layers, filled_layers[[1]], method = "bilinear")
  } else {
    static_aligned <- static_layers
  }
  
  # Combine climate + static
  layers_final <- c(filled_layers, static_aligned)
  cat("Added:", paste(names(static_aligned), collapse = ", "), "\n")
  cat("   Total layers:", nlyr(layers_final), "\n\n")
  
  # Verification
  cat("Verification:\n")
  final_vars <- names(layers_final)
  missing_vars <- setdiff(selected_var_names, final_vars)
  
  if (length(missing_vars) > 0) {
    cat("Warning: Missing", length(missing_vars), "expected variables:\n")
    for (v in missing_vars) {
      cat("       -", v, "\n")
    }
  } else {
    cat("All VIF-selected variables present!\n")
  }
  
  extra_vars <- setdiff(final_vars, selected_var_names)
  if (length(extra_vars) > 0) {
    cat("Warning:", length(extra_vars), "unexpected variables present\n")
  }
  cat("\n")
  
  # Save final stack
  final_file <- paste0(ssp, "_layers_final_", year, ".tif")
  cat("Saving final stack...\n")
  writeRaster(layers_final, final_file, overwrite = TRUE,
              filetype = "GTiff", gdal = c("TILED=YES", "COMPRESS=LZW", "PREDICTOR=2"))
  cat("Saved:", final_file, "\n")
  
  # Summary
  cat("\n───────────────────────────────────────────────\n")
  cat("✓", ssp, "processing complete\n")
  cat("   Output:", final_file, "\n")
  cat("   Layers:", nlyr(layers_final), "\n")
  cat("   - Climate (VIF-selected + interpolated):", nlyr(filled_layers), "\n")
  cat("   - Static (from current, previously interpolated):", nlyr(static_aligned), "\n")
  cat("───────────────────────────────────────────────\n")
}
