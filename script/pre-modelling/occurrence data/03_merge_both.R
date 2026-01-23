################################################################################
# Merge OBIS and GBIF Occurrence Data
################################################################################
# 
# Purpose: Combine OBIS and GBIF occurrence data for each species
#          Creates merged files even if species only has data from one source
#          Removes duplicate coordinates across data sources
#
# Input:   - species_list.csv
#          - GBIF files: occurrences_0825/*_gbif_occurrences_2025-08-19.csv
#          - OBIS files: occurrences_0825/*_obis_occurrences_2025-08-19.csv
# Output:  - Merged CSV files: occurrences_0825/occurrences_merged/*_merged_2025-08-19.csv
#          - Summary statistics: occurrences_0825/occurrences_merged/merged_summary_2025-08-19.csv
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-06
################################################################################

library(dplyr)

# Define directories
base_dir <- "occurrences_0825"
output_dir <- file.path(base_dir, "occurrences_merged")

# Create output directory
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# Load species list
species_list_file <- "species_list.csv"

if (!file.exists(species_list_file)) {
  stop("Species list file not found: ", species_list_file)
}

species_list <- read.csv(species_list_file, stringsAsFactors = FALSE)

if (!"Species" %in% colnames(species_list)) {
  stop("'Species' column not found in species_list.csv")
}

# Define analysis date -----------------------------------------------------
# IMPORTANT: This date should match when scripts 01 and 02 were run
# For the published analysis, data were downloaded on 2025-08-19
# Change this date if you re-run the data download scripts
output_date <- "2025-08-19"

cat("Processing", nrow(species_list), "species\n")
cat("Input directory:", base_dir, "\n")
cat("Output directory:", output_dir, "\n")
cat("Output date:", output_date, "\n\n")

# Initialize summary list
summary_list <- list()

# Process each species
for (i in seq_along(species_list$Species)) {
  species_name <- species_list$Species[i]
  cat(paste0("[", i, "/", nrow(species_list), "] Processing: ", species_name, "\n"))
  
  # Clean species name for file matching
  clean_name <- gsub(" ", "_", tolower(species_name))
  
  # Define expected file paths
  gbif_file <- file.path(base_dir, paste0(clean_name, "_gbif_occurrences_", output_date, ".csv"))
  obis_file <- file.path(base_dir, paste0(clean_name, "_obis_occurrences_", output_date, ".csv"))
  
  # Initialize data frames
  gbif_data <- data.frame(longitude = numeric(0), 
                          latitude = numeric(0), 
                          occurrenceStatus = numeric(0),
                          source = character(0))
  
  obis_data <- data.frame(longitude = numeric(0), 
                          latitude = numeric(0), 
                          occurrenceStatus = numeric(0),
                          source = character(0))
  
  # Load GBIF data if available
  if (file.exists(gbif_file)) {
    gbif_data <- read.csv(gbif_file, stringsAsFactors = FALSE)
    
    # Ensure required columns exist
    if (!"occurrenceStatus" %in% names(gbif_data)) {
      gbif_data$occurrenceStatus <- 1
    }
    if (!"source" %in% names(gbif_data)) {
      gbif_data$source <- "GBIF"
    }
    
    # Keep only needed columns (in case there are extra)
    gbif_data <- gbif_data %>%
      select(longitude, latitude, occurrenceStatus, source)
    
    cat("Loaded", nrow(gbif_data), "GBIF records\n")
  } else {
    cat("No GBIF file found\n")
  }
  
  # Load OBIS data if available
  if (file.exists(obis_file)) {
    obis_data <- read.csv(obis_file, stringsAsFactors = FALSE)
    
    # Ensure source column exists
    if (!"source" %in% names(obis_data)) {
      obis_data$source <- "OBIS"
    }
    
    # Keep only needed columns (in case there are extra)
    obis_data <- obis_data %>%
      select(longitude, latitude, occurrenceStatus, source)
    
    cat("Loaded", nrow(obis_data), "OBIS records\n")
  } else {
    cat("No OBIS file found\n")
  }
  
  # Check if we have any data
  if (nrow(gbif_data) == 0 && nrow(obis_data) == 0) {
    cat("No data available from either source, skipping\n\n")
    next
  }
  
  # Merge and deduplicate
  merged <- bind_rows(obis_data, gbif_data) %>%
    distinct(longitude, latitude, occurrenceStatus, .keep_all = TRUE)
  
  # Save merged file
  output_file <- file.path(output_dir, paste0(clean_name, "_merged_", output_date, ".csv"))
  write.csv(merged, output_file, row.names = FALSE)
  
  cat("Saved", nrow(merged), "merged records\n")
  cat("File:", basename(output_file), "\n")
  
  # Calculate summary statistics
  summary_list[[i]] <- tibble(
    species = species_name,
    total_records = nrow(merged),
    obis_records = sum(merged$source == "OBIS", na.rm = TRUE),
    gbif_records = sum(merged$source == "GBIF", na.rm = TRUE),
    presences = sum(merged$occurrenceStatus == 1, na.rm = TRUE),
    absences = sum(merged$occurrenceStatus == 0, na.rm = TRUE)
  )
  
  cat("\n")
}

# Combine summary statistics
merged_summary <- bind_rows(summary_list)

# Display summary
cat("\n" ,"=" , rep("=", 70), "\n", sep = "")
cat("Merge Summary:\n")
cat("=", rep("=", 70), "\n", sep = "")
print(merged_summary, n = Inf)
cat("\n")

# Save summary
summary_file <- file.path(output_dir, paste0("merged_summary_", output_date, ".csv"))
write.csv(merged_summary, summary_file, row.names = FALSE)

cat("Summary saved to:", basename(summary_file), "\n")

cat("\nNext step: Run 04_thinning.R\n")
