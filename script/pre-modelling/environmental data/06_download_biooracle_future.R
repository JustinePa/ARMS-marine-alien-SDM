################################################################################
# SCRIPT 6: Download Future Bio-ORACLE Environmental Layers
################################################################################
# 
# Purpose: Download future climate projection layers from Bio-ORACLE for 2100
#          under three SSP scenarios (1-2.6, 2-4.5, 5-8.5)
#          CLIMATE VARIABLES ONLY - no terrain/bathymetry needed
#          Downloads complete datasets; filtering to VIF-selected vars in Script 7   
#
# Outputs: 
#   - layers_future/ssp126_2100/depthmean/*.nc
#   - layers_future/ssp126_2100/depthsurf/*.nc
#   - Similar for ssp245 and ssp585
#
# Note:    Bio-ORACLE downloads by dataset (e.g., o2 comes with mean, min, max)
#          Filtering to VIF-selected variables happens in Script 7
#          Bathymetry and distance will come from myExpl_final.tif (Script 7)
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(terra)
library(biooracler)

cat("DOWNLOADING FUTURE BIO-ORACLE LAYERS\n")

setwd("C:/biomod2_git/test")

# Define output directory
future_dir <- "layers_future"
if (!dir.exists(future_dir)) dir.create(future_dir)

# Define SSP scenarios and depth levels
ssp_scenarios <- c("ssp126", "ssp245", "ssp585")
depth_levels <- c("depthmean", "depthsurf")
year <- "2100"

cat("Configuration:\n")
cat("   Scenarios:", paste(ssp_scenarios, collapse = ", "), "\n")
cat("   Target year:", year, "\n")
cat("   Depth levels:", paste(depth_levels, collapse = ", "), "\n\n")
cat("   Note: Bathymetry/distance will come from myExpl_final.tif\n\n")

# Create folder structure for all scenarios
cat("Creating directory structure...\n")
for (ssp in ssp_scenarios) {
  ssp_dir <- file.path(future_dir, paste0(ssp, "_", year))
  if (!dir.exists(ssp_dir)) dir.create(ssp_dir)
  
  for (depth in depth_levels) {
    depth_dir <- file.path(ssp_dir, depth)
    if (!dir.exists(depth_dir)) dir.create(depth_dir)
  }
}
cat("Directories created\n\n")

# Time constraints for 2100 projections (centered on 2090-2100 period)
constraints_future <- list(
  time = c("2090-01-01T00:00:00Z", "2090-01-01T00:00:00Z")
)

cat(" Note: Downloading complete datasets from Bio-ORACLE\n")
cat("   Filtering to VIF-selected variables will happen in Script 7\n")
cat("   Bathymetry and distance will come from myExpl_final.tif\n\n")

# Define climate variables to download
# Note: Downloads full datasets (mean, min, max when available)
#       Filtering to VIF-selected happens in Script 7
variable_map <- list(
  o2 = list(vars = c("o2_mean", "o2_min", "o2_max")),
  chl = list(vars = "chl_mean"),
  thetao = list(vars = c("thetao_mean", "thetao_min", "thetao_max")),
  ph = list(vars = "ph_mean"),
  po4 = list(vars = "po4_mean"),
  so = list(vars = "so_mean"),
  phyc = list(vars = "phyc_mean"),
  no3 = list(vars = "no3_mean"),
  dfe = list(vars = "dfe_mean"),
  si = list(vars = "si_mean"),
  siconc = list(vars = c("siconc_mean", "siconc_max")),
  sws = list(vars = "sws_mean")
)

# Helper function to build dataset list for one SSP + depth level
build_datasets <- function(ssp, depth) {
  datasets <- list()
  
  for (var_name in names(variable_map)) {
    # Skip siconc and chl for depthmean (not available)
    if (depth == "depthmean" && var_name %in% c("siconc", "chl")) next
    
    dataset_id <- paste(var_name, ssp, "2020_2100", depth, sep = "_")
    datasets[[length(datasets) + 1]] <- list(
      dataset_id = dataset_id,
      variables = variable_map[[var_name]]$vars,
      constraints = constraints_future
    )
  }
  
  return(datasets)
}

# Main download loop
cat("Starting downloads from Bio-ORACLE...\n")
cat("This will take 30-60 minutes depending on connection speed\n\n")

for (ssp in ssp_scenarios) {
  cat("Processing scenario:", ssp, "\n")
  
  ssp_year <- paste0(ssp, "_", year)
  
  for (depth in c("depthmean", "depthsurf")) {
    cat("Downloading:", depth, "layers\n")
    
    depth_dir <- file.path(future_dir, ssp_year, depth)
    datasets <- build_datasets(ssp, depth)
    
    for (dataset in datasets) {
      cat("   Dataset:", dataset$dataset_id, "\n")
      cat("   Variables:", paste(dataset$variables, collapse = ", "), "\n")
      
      tryCatch({
        download_layers(
          dataset_id = dataset$dataset_id,
          variables = dataset$variables,
          constraints = dataset$constraints,
          directory = depth_dir
        )
        cat("Complete\n\n")
      }, error = function(e) {
        cat(" Error:", e$message, "\n")
        cat("   Continuing to next dataset...\n\n")
      })
    }
  }
}

cat("ALL DOWNLOADS COMPLETE\n")

# Summary
cat("Downloaded files summary:\n")
for (ssp in ssp_scenarios) {
  ssp_year <- paste0(ssp, "_", year)
  all_files <- list.files(file.path(future_dir, ssp_year), 
                          pattern = "\\.nc$", recursive = TRUE)
  cat("   ", ssp, ":", length(all_files), "files\n")
}

cat("\n Data location:", normalizePath(future_dir), "\n")

cat("\n Important notes:\n")
cat("   ✓ Downloaded complete climate datasets\n")
cat("   ✓ Filtering to VIF-selected variables in Script 7\n")
cat("   ✓ Bathymetry and distance from myExpl_final.tif (Script 7)\n")
cat("   ✓ This ensures consistency between current and future\n")
cat("\n Next step: Run Script 7 (process_future_layers.R)\n")
