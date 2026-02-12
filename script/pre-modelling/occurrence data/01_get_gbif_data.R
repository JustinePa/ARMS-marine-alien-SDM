################################################################################
# GBIF Occurrence Data Download for Marine Species
################################################################################
# 
# Purpose: Automated download and curation of GBIF occurrence records for 
#          multiple marine species from a provided species list
#
# Input:   species_list.csv (must contain a column named "Species")
# Output:  Individual CSV files per species in occurrences_0825/ directory
#
# Filtering criteria:
#   - No geospatial issues
#   - Has coordinates
#   - Occurrence status = PRESENT
#   - Coordinate uncertainty < 5000m (or NULL)
#   - Basis of record: HUMAN_OBSERVATION, MACHINE_OBSERVATION, MATERIAL_SAMPLE, 
#                      OCCURRENCE, OBSERVATION
#   - Date range: 2000-01-01 to 2025-08-01 (time of analysis)
#
# Requirements:
#   - GBIF account credentials have to be added in the script
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-02-12
################################################################################


# Load required packages
library(rgbif)

# Set GBIF credentials
options(gbif_user = "")
options(gbif_email = "")
options(gbif_pwd  = "")

# Define input/output paths
species_list_file <- "species_list.csv"
output_dir <- "occurrences_0825"

# Validate input file exists
if (!file.exists(species_list_file)) {
  stop(paste("Species list file not found:", species_list_file))
}

# Load species list
species_list <- read.csv(species_list_file, stringsAsFactors = FALSE)

# Validate Species column exists
if (!"Species" %in% colnames(species_list)) {
  stop("'Species' column not found in species_list.csv")
}

# Create output directory if needed
if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

# Define date filter
start_date <- as.Date("2000-01-01")
end_date <- as.Date("2025-08-01")

cat("Processing", nrow(species_list), "species\n")
cat("Date range:", start_date, "to", end_date, "\n\n")

# Loop over species
for (i in seq_along(species_list$Species)) {
  species_name <- species_list$Species[i]
  cat(paste0("[", i, "/", nrow(species_list), "] Processing: ", species_name, "\n"))
  
  # Clean species name for file naming
  clean_name <- gsub(" ", "_", tolower(species_name))
  outfile <- paste0(output_dir, "/", clean_name, "_gbif_occurrences_", Sys.Date(), ".csv")
  # NOTE: Output filenames include the download date (Sys.Date()).
  # The published analysis used 2025-08-19. Downstream scripts (03_merge_both.R,
  # 04_thinning.R) reference this date explicitly — update them if re-downloading
  
  # Skip if file already exists
  existing_files <- list.files(
    path = output_dir, 
    pattern = paste0("^", clean_name, "_gbif_occurrences_.*\\.csv$")
  )
  
  if (length(existing_files) > 0) {
    cat("  ✅ Already exists, skipping.\n\n")
    next
  }
  
  # Get taxonKey safely
  taxonKey <- try(name_backbone(name = species_name)$usageKey, silent = TRUE)
  if (inherits(taxonKey, "try-error") || is.null(taxonKey)) {
    cat("Could not find taxonKey for:", species_name, "\n\n")
    next
  }
  
  # Launch GBIF download
  occ_dl <- try(
    occ_download(
      pred("hasGeospatialIssue", FALSE),
      pred("hasCoordinate", TRUE),
      pred("occurrenceStatus", "PRESENT"),
      pred("taxonKey", taxonKey),
      pred_or(
        pred_lt("coordinateUncertaintyInMeters", 5000),
        pred_isnull("coordinateUncertaintyInMeters")
      ),
      format = "SIMPLE_CSV"
    ),
    silent = TRUE
  )
  
  if (inherits(occ_dl, "try-error")) {
    cat("Failed to start download.\n\n")
    next
  }
  
  # Wait for GBIF to process the request
  cat("Waiting for GBIF to prepare download...\n")
  occ_download_wait(occ_dl)
  
  # Import downloaded data
  occ_data <- try(
    occ_download_import(occ_download_get(occ_dl)),
    silent = TRUE
  )
  
  if (inherits(occ_data, "try-error")) {
    cat("Failed to import data.\n\n")
    next
  }
  
  # Apply post-download filtering
  # 1. Filter by basis of record
  # Keep only observation and specimen-based records
  gbif_curated <- occ_data[
    occ_data$basisOfRecord %in% c(
      "HUMAN_OBSERVATION", 
      "MACHINE_OBSERVATION", 
      "MATERIAL_SAMPLE", 
      "OCCURRENCE", 
      "OBSERVATION"
    ), 
  ]
  
  # 2. Filter by date range
  gbif_curated$date <- as.Date(gbif_curated$eventDate)
  gbif_curated <- gbif_curated[
    !is.na(gbif_curated$date) &
    gbif_curated$date >= start_date &
    gbif_curated$date <= end_date, 
  ]
  
  # 3. Extract coordinates only
  # Keep only spatial information needed for downstream modeling
  gbif_curated <- gbif_curated[, c("decimalLongitude", "decimalLatitude")]
  colnames(gbif_curated) <- c("longitude", "latitude")
  
  # 4. Remove duplicates
  gbif_curated <- unique(gbif_curated)
  
  # 5. Add occurrence status column
  # All records are presences (occurrenceStatus = 1)
  gbif_curated$occurrenceStatus <- 1
  
  # Save to file
  write.csv(gbif_curated, outfile, row.names = FALSE)
  cat("Saved", nrow(gbif_curated), "occurrences to:", basename(outfile), "\n\n")
}


downloaded_files <- list.files(output_dir, pattern = "_gbif_occurrences_.*\\.csv$")
cat("Total species files in", output_dir, ":", length(downloaded_files), "\n")
cat("Next step: Run 02_get_obis_data.R\n")

