################################################################################
# SCRIPT 1: Download Current Bio-ORACLE Environmental Layers
################################################################################
# 
# Purpose: Download baseline (2000-2020) environmental predictors from Bio-ORACLE
#
# Outputs: 
#   - layers/depthmean/*.nc - Depth-averaged environmental layers
#   - layers/depthsurf/*.nc - Surface environmental layers  
#   - layers/terrain/*.nc - Bathymetry layer
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(terra)
library(biooracler)

# Run this script from your project root directory, e.g.:
# setwd("/path/to/your/project")
# All outputs will be written relative to that directory.

# Define output directory
dir <- "layers"
if (!dir.exists(dir)) dir.create(dir)

# Create subdirectories for different depth levels
subdirs <- c("depthmean", "depthsurf", "terrain")
for (subdir in subdirs) {
  subdir_path <- file.path(dir, subdir)
  if (!dir.exists(subdir_path)) dir.create(subdir_path)
}

cat("Created output directories\n\n")

# Time constraints for baseline period
constraints <- list(
  time = c("2001-01-01T00:00:00Z", "2010-01-01T00:00:00Z")
  # Note: This represents the 2000-2018/2020 baseline period
)

# Separate constraints for terrain (no time dimension)
constraints_terrain <- list()

cat("Downloading baseline period: 2000-2020\n\n")

# Define datasets organized by depth level
datasets_list <- list(
  
  # TERRAIN (static, no time dimension)
  terrain = list(
    list(
      dataset_id = "terrain_characteristics",
      variables = c("bathymetry_mean"),
      constraints = constraints_terrain
    )
  ),
  
  # DEPTH-AVERAGED LAYERS
  depthmean = list(
    list(dataset_id = "o2_baseline_2000_2018_depthmean", 
         variables = c("o2_mean", "o2_min", "o2_max"), 
         constraints = constraints),
    list(dataset_id = "chl_baseline_2000_2018_depthmean", 
         variables = "chl_mean", 
         constraints = constraints),
    list(dataset_id = "thetao_baseline_2000_2019_depthmean", 
         variables = c("thetao_mean", "thetao_min", "thetao_max"), 
         constraints = constraints),
    list(dataset_id = "ph_baseline_2000_2018_depthmean", 
         variables = c("ph_mean"), 
         constraints = constraints),
    list(dataset_id = "po4_baseline_2000_2018_depthmean", 
         variables = c("po4_mean"), 
         constraints = constraints),
    list(dataset_id = "so_baseline_2000_2019_depthmean", 
         variables = c("so_mean"), 
         constraints = constraints),
    list(dataset_id = "phyc_baseline_2000_2020_depthmean", 
         variables = c("phyc_mean"), 
         constraints = constraints),
    list(dataset_id = "no3_baseline_2000_2018_depthmean", 
         variables = c("no3_mean"), 
         constraints = constraints),
    list(dataset_id = "dfe_baseline_2000_2018_depthmean", 
         variables = c("dfe_mean"), 
         constraints = constraints),
    list(dataset_id = "si_baseline_2000_2018_depthmean", 
         variables = c("si_mean"), 
         constraints = constraints),
    list(dataset_id = "sws_baseline_2000_2019_depthmean", 
         variables = c("sws_mean"), 
         constraints = constraints)
  ),
  
  # SURFACE LAYERS
  depthsurf = list(
    list(dataset_id = "o2_baseline_2000_2018_depthsurf", 
         variables = c("o2_mean", "o2_min", "o2_max"), 
         constraints = constraints),
    list(dataset_id = "chl_baseline_2000_2018_depthsurf", 
         variables = c("chl_mean"), 
         constraints = constraints),
    list(dataset_id = "thetao_baseline_2000_2019_depthsurf", 
         variables = c("thetao_mean", "thetao_min", "thetao_max"), 
         constraints = constraints),
    list(dataset_id = "ph_baseline_2000_2018_depthsurf", 
         variables = c("ph_mean"), 
         constraints = constraints),
    list(dataset_id = "po4_baseline_2000_2018_depthsurf", 
         variables = c("po4_mean"), 
         constraints = constraints),
    list(dataset_id = "so_baseline_2000_2019_depthsurf", 
         variables = c("so_mean"), 
         constraints = constraints),
    list(dataset_id = "phyc_baseline_2000_2020_depthsurf", 
         variables = c("phyc_mean"), 
         constraints = constraints),
    list(dataset_id = "no3_baseline_2000_2018_depthsurf", 
         variables = c("no3_mean"), 
         constraints = constraints),
    list(dataset_id = "dfe_baseline_2000_2018_depthsurf", 
         variables = c("dfe_mean"), 
         constraints = constraints),
    list(dataset_id = "par_mean_baseline_2000_2020_depthsurf", 
         variables = c("par_mean_mean"), # Note the different naming pattern here.
         constraints = constraints),
    list(dataset_id = "si_baseline_2000_2018_depthsurf", 
         variables = c("si_mean"), 
         constraints = constraints),
    list(dataset_id = "siconc_baseline_2000_2020_depthsurf", 
         variables = c("siconc_mean", "siconc_max"), 
         constraints = constraints),
    list(dataset_id = "sws_baseline_2000_2019_depthsurf", 
         variables = c("sws_mean"), 
         constraints = constraints)
  )
)

# Download all layers
cat("Starting downloads from Bio-ORACLE...\n\n")

for (depth in names(datasets_list)) {
  cat("Processing:", depth, "\n")
  
  depth_dir <- file.path(dir, depth)
  
  for (dataset in datasets_list[[depth]]) {
    dataset_id <- dataset$dataset_id
    variables <- dataset$variables
    ds_constraints <- dataset$constraints
    
    cat("Downloading:", dataset_id, "\n")
    cat("Variables:", paste(variables, collapse = ", "), "\n")
    
    # Download layers
    download_layers(
      dataset_id, 
      variables = variables, 
      constraints = ds_constraints, 
      directory = depth_dir
    )
    
    cat("Complete\n\n")
  }
}

cat("All downloads complete!\n")

# List downloaded files
all_files <- list.files(dir, pattern = "\\.nc$", recursive = TRUE, full.names = TRUE)
cat("Downloaded", length(all_files), "files:\n")
cat("   - Depth-mean:", 
    length(list.files(file.path(dir, "depthmean"), pattern = "\\.nc$")), "files\n")
cat("   - Depth-surf:", 
    length(list.files(file.path(dir, "depthsurf"), pattern = "\\.nc$")), "files\n")
cat("   - Terrain:", 
    length(list.files(file.path(dir, "terrain"), pattern = "\\.nc$")), "files\n")

cat("\n Data location:", normalizePath(dir), "\n")
cat("\n Next step: Run Script 02 (calculate_distance_to_coast.R)\n")
