################################################################################
# Spatial Thinning of Species Occurrence Data
################################################################################
# 
# Purpose: Apply spatial thinning to reduce sampling bias in occurrence data
#          Uses spThin algorithm to ensure minimum distance between points
#
# Input:   Merged occurrence files from script 03_merge_both.R
#          - Expected location: .../data/merged_occurrences_0825/*_merged_YYYY-MM-DD.csv
# Output:  Spatially thinned occurrence files
#          - Output location: .../data/occurrences_thinned_0825/*_merged_thinned_YYYY-MM-DD.csv
#          - Summary statistics: .../data/occurrences_thinned_0825/thinning_summary.csv
#
# Thinning parameters:
#   - Distance: 10 km (thin.par = 10)
#
# Execution:
#   This script is designed for parallel execution on HPC clusters using SLURM
#   task arrays. Each task processes one species file.
#   
#   Usage: Rscript 04_thinning.R <task_id>
#   
#   Example SLURM submission:
#   #SBATCH --array=1-70  # for 70 species
#   Rscript 04_thinning.R $SLURM_ARRAY_TASK_ID
#
# Reproducibility:
#   Random seed is set based on task_id to ensure reproducibility while
#   maintaining independence between species
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-02-12
################################################################################

library(spThin)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  stop("Usage: Rscript 04_thinning.R <task_id>")
}
task_id <- as.numeric(args[1])

# Using task_id ensures each species has a unique but reproducible seed
set.seed(1000 + task_id)

indir <- file.path("occurrences_0825", "occurrences_merged")
outdir <- "occurrences_thinned_0825"
if (!dir.exists(outdir)) {
  dir.create(outdir, recursive = TRUE)
  cat("Created output directory:", outdir, "\n")
}

# List merged files
output_date <- "2025-08-19"  # IMPORTANT: must match date used in scripts 01 and 02
files <- list.files(indir, pattern = paste0("_merged_", output_date, "\\.csv$"), full.names = TRUE)
if (length(files) == 0) {
  stop("No merged files found in ", indir)
}

cat("Found", length(files), "species files\n")
cat("Processing task", task_id, "of", length(files), "\n")
cat("Random seed:", 1000 + task_id, "\n")

# Validate task ID
if (task_id > length(files)) {
  stop("Task ID exceeds number of files")
}

# Select file for this task
file <- files[task_id]
cat("Processing:", file, "\n")

# Read data
dat <- read.csv(file, stringsAsFactors = FALSE)
cat("Loaded", nrow(dat), "total records\n")

# Keep only presences
pres <- dat %>% filter(occurrenceStatus == 1)
cat("  -", nrow(pres), "presence records\n")

# Apply spatial thinning to presences points
if (nrow(pres) < 2) {
  cat("Not enough presences to thin (<2 points)\n")
  cat("Keeping all records without thinning\n\n")
  final <- dat
  thinned <- pres
} else {
  # Prepare dataset for spThin
  # Extract species name from filename (remove "_merged_..." suffix)
  dataset_thin <- data.frame(
    Species = gsub("_merged_.*", "", basename(file)),  # species name from filename
    Longitude = pres$longitude,
    Latitude  = pres$latitude
  )
  
  # Run thinning
  thin_result <- thin(
    loc.data = dataset_thin,
    lat.col = "Latitude",
    long.col = "Longitude",
    spec.col = "Species",
    thin.par = 10,     # thinning distance in km
    reps = 1, # single rep sufficient given reproducible seed (set.seed above)
    locs.thinned.list.return = TRUE,
    write.files = FALSE,
    verbose = FALSE
  )
  
  # Extract thinned coords
  thinned_coords <- thin_result[[1]]
  
  if (!is.null(thinned_coords) && nrow(thinned_coords) > 0) {
    # Match thinned coordinates back to original data
    # This preserves the source information
    thinned <- pres %>%
      semi_join(thinned_coords, by = c("longitude" = "Longitude",
                                       "latitude"  = "Latitude"))
  } else {
    cat("Thinning returned no points, keeping all presences\n")
    thinned <- pres
  }

  cat("Retained", nrow(thinned), "presence records after thinning\n")
  cat("Removed", nrow(pres) - nrow(thinned), "presence records\n\n")

  # Combine thinned presences with original absences
  final <- bind_rows(thinned, dat %>% filter(occurrenceStatus == 0))
}

# Save output
outfile <- file.path(outdir, gsub("_merged_", "_merged_thinned_", basename(file)))
write.csv(final, outfile, row.names = FALSE)
cat("Thinned file saved to:", outfile, "\n")

# Create summary row
species <- gsub("_merged_.*", "", basename(file))
summary_row <- tibble(
  species = species,
  pres_before = nrow(pres),
  pres_after  = nrow(thinned),
  pres_removed = nrow(pres) - nrow(thinned),
  pres_retained_pct = if (nrow(pres) > 0) round(100 * nrow(thinned) / nrow(pres), 1) else NA,
  absences    = sum(dat$occurrenceStatus == 0),
  total_before = nrow(dat),
  total_after  = nrow(final)
)

# Save/append summary
summary_file <- file.path(outdir, "thinning_summary.csv")
if (!file.exists(summary_file)) {
  write.csv(summary_row, summary_file, row.names = FALSE)
  cat("Created summary file:", basename(summary_file), "\n")
} else {
  write.table(summary_row, summary_file, row.names = FALSE,
              col.names = FALSE, sep = ",", append = TRUE)
  cat("Appended to summary file:", basename(summary_file), "\n")
}

cat("Task", task_id, "complete!\n")
