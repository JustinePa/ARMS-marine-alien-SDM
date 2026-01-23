################################################################################
# SCRIPT 5: VIF Analysis - Collinearity Reduction
################################################################################
# 
# Purpose: Identify and remove highly collinear environmental predictors
#          using Variance Inflation Factor (VIF) analysis
#
# Input:   current_layers_interpolated.tif (from Script 04)
# Output:  myExpl_final.tif - Final predictor stack (VIF < 10)
#          selected_var_names.txt - Variables retained
#          removed_var_names.txt - Variables removed
#
# Method:  Stepwise VIF selection with threshold = 10
#          Variables with VIF > 10 indicate high collinearity
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(terra)
library(usdm)

cat("VIF ANALYSIS - Collinearity Reduction\n")

setwd("C:/biomod2_git/test")

# Load interpolated layers
cat(" Loading interpolated environmental layers...\n")
myExpl_combined <- rast("current_layers_interpolated.tif")
cat("   Total predictors:", nlyr(myExpl_combined), "\n")

# Step 1: Run VIF analysis
cat("Step 1/4: Running VIF analysis (VIF threshold = 10)...\n")

myExpl_vif <- vifstep(myExpl_combined, th = 10)

# Extract results
selected_var_names <- myExpl_vif@results$Variables
original_names <- names(myExpl_combined)
removed_names <- setdiff(original_names, selected_var_names)

cat("   ✅ VIF analysis complete\n\n")

# Step 2: Display results
cat("VIF RESULTS\n")
cat("Original predictors:", length(original_names), "\n")
cat("Retained predictors:", length(selected_var_names), "\n")
cat("Removed predictors:", length(removed_names), "\n\n")

cat(" RETAINED VARIABLES (VIF < 10):\n")
for (i in seq_along(selected_var_names)) {
  cat("   ", i, ". ", selected_var_names[i], "\n", sep = "")
}
cat("\n")

if (length(removed_names) > 0) {
  cat(" REMOVED VARIABLES (VIF ≥ 10):\n")
  for (i in seq_along(removed_names)) {
    cat("   ", i, ". ", removed_names[i], "\n", sep = "")
  }
  cat("\n")
}

# Save VIF results to text files
cat(" Saving VIF results to text files...\n")
writeLines(selected_var_names, "selected_var_names.txt")
writeLines(removed_names, "removed_var_names.txt")
cat("SAVED: selected_var_names.txt\n")
cat("SAVED: removed_var_names.txt\n\n")

# Step 3: Create subset with selected variables
cat("Step 2/4: Creating VIF-filtered stack...\n")
myExpl_done <- myExpl_combined[[selected_var_names]]
writeRaster(myExpl_done, "myExpl.tif", overwrite = TRUE)
cat("Saved: myExpl.tif\n\n")

# Step 4: Adjust for future projection compatibility
cat("Step 3/4: Adjusting for future projection compatibility...\n")
cat("Note: Some variables aren't available for future projections\n\n")

# Check if problematic variables are in the selected set
needs_replacement <- FALSE

if ("chl_mean_depthmean" %in% selected_var_names) {
  cat("Replacing chl_mean_depthmean with chl_mean_depthsurf\n")
  cat("Reason: Depth-mean chlorophyll not available for future\n")
  selected_var_names <- setdiff(selected_var_names, "chl_mean_depthmean")
  selected_var_names <- c(selected_var_names, "chl_mean_depthsurf")
  needs_replacement <- TRUE
}

if ("par_mean_mean_depthsurf" %in% selected_var_names) {
  cat("Removing par_mean_mean_depthsurf\n")
  cat("Reason: PAR not available for future projections\n")
  selected_var_names <- setdiff(selected_var_names, "par_mean_mean_depthsurf")
  needs_replacement <- TRUE
}

if (needs_replacement) {
  cat("Adjustments complete\n\n")
} else {
  cat("No adjustments needed\n\n")
}

# Step 5: Create final stack
cat("Step 4/4: Creating final predictor stack...\n")
myExpl_final <- myExpl_combined[[selected_var_names]]

cat("   Final predictors:", nlyr(myExpl_final), "\n")
cat("   Layer names:\n")
for (i in 1:nlyr(myExpl_final)) {
  cat("     ", i, ". ", names(myExpl_final)[i], "\n", sep = "")
}
cat("\n")

# Save final stack
cat("Saving final predictor stack...\n")
writeRaster(myExpl_final, "myExpl_final.tif", overwrite = TRUE,
            filetype = "GTiff", gdal = c("TILED=YES", "COMPRESS=LZW", "PREDICTOR=2"))
cat("   ✅ myExpl_final.tif\n\n")

# Update selected variables list
writeLines(selected_var_names, "selected_var_names.txt")

# Step 6: Summary and recommendations
cat("VIF ANALYSIS COMPLETE\n")

cat("FINAL STATISTICS:\n")
cat("   Original predictors:", length(original_names), "\n")
cat("   Final predictors:", length(selected_var_names), "\n")
cat("   Reduction:", length(original_names) - length(selected_var_names), 
    "variables (",
    round((length(original_names) - length(selected_var_names)) / length(original_names) * 100, 1),
    "%)\n\n")

cat("OUTPUT FILES:\n")
cat("   - myExpl_final.tif: Final predictor stack for current conditions\n")
cat("   - selected_var_names.txt: Variables to use for modeling\n")
cat("   - removed_var_names.txt: Variables removed due to collinearity\n\n")

cat("IMPORTANT FOR FUTURE PROJECTIONS:\n")
cat("   Use the variables in selected_var_names.txt for all future scenarios\n")
cat("   This ensures model consistency between current and future conditions\n\n")

cat("Next step: Run Script 06 (download_biooracle_future.R)\n")
