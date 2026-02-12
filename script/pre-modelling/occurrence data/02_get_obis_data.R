################################################################################
# OBIS Occurrence Data Download for Marine Species
################################################################################
# 
# Purpose: Automated download and curation of OBIS (Ocean Biodiversity 
#          Information System) occurrence records for multiple marine species
#
# Input:   species_list.csv (must contain a column named "Species")
# Output:  Individual CSV files per species in occurrences_0825/ directory
#
# Filtering criteria:
#   - Basis of record: HumanObservation, Occurrence, MaterialSample
#   - Date range: 2000-01-01 to 2025-08-01 (time of analysis)
#   - Complete coordinates (no NAs)
#
# Citation:
#   OBIS (2025) Ocean Biodiversity Information System. 
#   Intergovernmental Oceanographic Commission of UNESCO. 
#   www.obis.org. Accessed: [DATE]
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-02-12
################################################################################

# Load required packages
library(robis)
library(dplyr)
library(lubridate)

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
  cat("Created output directory:", output_dir, "\n")
}

# Define date filter 
start_date <- as.Date("2000-01-01")
end_date <- as.Date("2025-08-01")

cat("Processing", nrow(species_list), "species from OBIS\n")
cat("Date range:", start_date, "to", end_date, "\n\n")

# Loop over species
for (i in seq_along(species_list$Species)) {
  species_name <- species_list$Species[i]
  cat(paste0("[", i, "/", nrow(species_list), "]  Processing OBIS for: ", species_name, "\n"))
  
  # Clean name for file path
  clean_name <- gsub(" ", "_", tolower(species_name))
  outfile <- paste0(output_dir, "/", clean_name, "_obis_occurrences_", Sys.Date(), ".csv")
  # NOTE: Output filenames include the download date (Sys.Date()).
  # The published analysis used 2025-08-19. Downstream scripts (03_merge_both.R,
  # 04_thinning.R) reference this date explicitly — update them if re-downloading.
  
  # Skip if already exists
  if (file.exists(outfile)) {
    cat("OBIS data already exists, skipping.\n\n")
    next
  }
  
  # Download OBIS data
  obis_data <- try(occurrence(species_name), silent = TRUE)
  
  if (inherits(obis_data, "try-error") || is.null(obis_data) || nrow(obis_data) == 0) {
    cat("No OBIS data found for", species_name, "\n\n")
    next
  }
  
  cat("Downloaded", nrow(obis_data), "records\n")
  
  # Filter basisOfRecord
  obis_curated <- obis_data %>%
    filter(basisOfRecord %in% c("HumanObservation", "Occurrence", "MaterialSample"))
  
  # Parse dates with multiple format support
  obis_curated <- obis_curated %>%
    mutate(
      date = tryCatch({
        parse_date_time(eventDate, 
                       orders = c("ymd HMS", "ymd", "mdy", "dmy", "Y-m-d", "m/d/Y"),
                       quiet = TRUE)
      }, 
      error = function(e) as.POSIXct(NA))
    )
  
  # Filter by date range
  obis_curated <- obis_curated %>%
    filter(!is.na(date) &
           date >= start_date &
           date <= end_date)
  
  # Keep only coordinates
  obis_curated <- obis_curated %>%
    select(decimalLongitude, decimalLatitude) %>%
    rename(longitude = decimalLongitude, 
           latitude = decimalLatitude)
  
  # Remove NAs and duplicates
  obis_curated <- obis_curated %>%
    na.omit() %>%
    filter(longitude >= -180 & longitude <= 180 & latitude  >=  -90 & latitude  <=  90) %>%
    distinct()
  
  # Add occurrence status column
  obis_curated$occurrenceStatus <- 1
  
  # Check if we have any data left after filtering
  if (nrow(obis_curated) == 0) {
    cat("No records remaining after filtering\n\n")
    next
  }
  
  # Save to CSV
  write.csv(obis_curated, outfile, row.names = FALSE)
  cat("Saved", nrow(obis_curated), "occurrences to:", basename(outfile), "\n\n")
}

obis_files <- list.files(output_dir, pattern = "_obis_occurrences_.*\\.csv$")
cat("Total OBIS species files:", length(obis_files), "\n")      
cat("Files saved to:", output_dir, "\n")
cat("\nNext step: Run 03_merge_both.R\n")

cat("\n Citation:\n")
cat("OBIS (", format(Sys.Date(), "%Y"), ") Ocean Biodiversity Information System.\n", sep = "")
cat("Intergovernmental Oceanographic Commission of UNESCO.\n")
cat("www.obis.org. Accessed:", format(Sys.Date(), "%Y-%m-%d"), "\n")


citation_text <- "OBIS. (accessed YYYY-MM-DD) Ocean Biodiversity Information System. Intergovernmental Oceanographic Commission of UNESCO. www.obis.org"


