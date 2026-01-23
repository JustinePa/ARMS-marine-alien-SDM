################################################################################
# Post-modelling: processing of species distribution model outputs
################################################################################
# 
# Raw SDM projections
#   → Land masking
#   → MEOW ecoregion masking (species-specific)
#   → Normalization (0–1)
#   → Species stacking
#   → Scenario deltas (future – current)
#   → Aggregation across species
#   → EMca normalization
#   → Ecoregion-scale statistics
#
# Note:
# EMwmeanByTSS = ensemble weighted mean suitability from biomod2 (scale 0–1000)
# EMca        = ensemble committee averaging output (scale 0–1000)
# All maps are converted to a 0–1 scale for comparison and aggregation.
#
# Author: Justine Pagnier
# Institution: University of Gothenburg
# Contact: justine.pagnier@gu.se
# Date Created: 2025-08-19
# Last Modified: 2026-01-23
################################################################################


library(terra)
library(dplyr)
library(tools)
library(ggplot2)
library(tidyr)
library(scales)
library(readr)
library(tidyterra)
library(patchwork)
library(sf)


setwd("C:/biomod2_git")

# -----------------------------
# 1) LAND MASK: remove land cells from EMwmean (0 in biomod's outputs)
# outputs: MASKED_species_....tif
# in folder: .../<sc>_proj/masked
# -----------------------------

# ---- Define a land mask from any env stack that matches your projections' grid
env_ref   <- rast("env_data/myExpl_shelf.tif")
landmask  <- is.na(env_ref["distance_to_land"])  # TRUE on land, FALSE at sea

# ---- Paths
proj_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/current_proj" # change here for different scenario
masked_proj_dir  <- file.path(proj_dir, "masked")
dir.create(masked_proj_dir, recursive = TRUE, showWarnings = FALSE)

# Grab all EMwmeanByTSS rasters (current projections)
emwmean_files <- list.files(
  proj_dir,
  pattern = "EMwmeanByTSS.*\\.(tif|tiff)$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(emwmean_files) == 0) {
  cat("⚠️ No EMwmeanByTSS rasters found in:", proj_dir, "\n")
}

for (f in emwmean_files) {
  base <- basename(f)
  species_code <- sub("_EMwmeanByTSS.*$", "", file_path_sans_ext(base))  # no-spaces code
  cat("🔄 Land-masking:", species_code, "\n")
  
  out_path <- file.path(masked_proj_dir, paste0("MASKED_", base))
  
  r <- rast(f)
  # Align to landmask grid if needed
  if (!compareGeom(r, landmask, stopOnError = FALSE)) {
    r <- project(r, landmask, method = "near")  # or "bilinear" for continuous
  }
  # Mask where landmask == TRUE (i.e., land)
  r_masked <- mask(r, landmask, maskvalues = TRUE)
  
  writeRaster(r_masked, out_path, filetype = "GTiff", overwrite = TRUE)
  cat("✅ Saved:", out_path, "\n")
}

# -----------------------------
# 2) MEOW MASK: keep only European ecoregions (per species)
# outputs: ALIENMASK_MASKED_species_....tif
# in folder: .../<sc>_proj/masked/alien
# -----------------------------

meow <- vect("C:/biomod2_git/MEOW_FINAL/MEOW/meow_ecos.shp")        # download from www.resourcewatch.org

alien_regions <- read.csv(                                          # csv with one column 'species' and one 'ecoregions', cf. Suppl. File 5
  "C:/biomod2_git/post_modelisation/alien_species_regions.csv",
  stringsAsFactors = FALSE
)

all_metro_ecoregions <- c(
  "South European Atlantic Shelf","North Sea","Southern Norway",
  "Northern Norway and Finnmark","Baltic Sea","Celtic Seas",
  "Adriatic Sea","Ionian Sea","Aegean Sea","Alboran Sea",
  "Western Mediterranean","Levantine Sea","Tunisian Plateau/Gulf of Sidra",
  "Faroe Plateau","North and East Iceland","North and East Barents Sea","South and West Iceland", "Black Sea"
) 

# Canonical species for mapping from filename codes
species_list <- c("AcartiaAcanthacartiatonsa",
                  "Amphibalanusamphitrite",
                  "Amphibalanuseburneus",
                  "Amphibalanusimprovisus",
                  "ApionsomaApionsomamisakianum",
                  "Arcuatulasenhousia",
                  "Ascidiellaaspersa",
                  "Asparagopsisarmata",
                  "Asparagopsistaxiformis",
                  "Aureliasolida",
                  "Austrominiusmodestus",
                  "Balanustrigonus",
                  "Boccardiaproboscidea",
                  "Bonnemaisoniahamifera",
                  "Botrylloidesviolaceus",
                  "Bugulaneritina",
                  "Caprellamutica",
                  "Caprellascaura",
                  "Corambeobscura",
                  "Cordylophoracaspia",
                  "Corellaeumyota",
                  "Crepidulafornicata",
                  "Cutleriamultifida",
                  "Dasysiphoniajaponica",
                  "Ensisleei",
                  "Evadneanonyx",
                  "Fenestrulinadelicia",
                  "Fibrocapsajaponica",
                  "Ficopomatusenigmaticus",
                  "Gammarustigrinus",
                  "Gonionemusvertens",
                  "Haloajaponica",
                  "Haminellasolitaria",
                  "Hemigrapsustakanoi",
                  "Herdmaniamomus",
                  "Hydroideselegans",
                  "Juxtacribrilinamutabilis",
                  "Marenzelleriaarctia",
                  "Marenzellerianeglecta",
                  "Marenzelleriaviridis",
                  "Melanothamnusharveyi",
                  "Mnemiopsisleidyi",
                  "Monocorophiumacherusicum",
                  "Monocorophiumsextonae",
                  "Neogobiusmelanostomus",
                  "Oithonadavisae",
                  "Ostreopsisovata",
                  "Palaemonelegans",
                  "Paracerceissculpta",
                  "Perophorajaponica",
                  "Petricolariapholadiformis",
                  "Polydoracornuta",
                  "Polydorawebsteri",
                  "Polysiphoniabrodiei",
                  "Potamopyrgusantipodarum",
                  "Pseudocalanusacuspes",
                  "Pseudocalanusmimus",
                  "Pseudodiaptomusmarinus",
                  "Rangiacuneata",
                  "Rhithropanopeusharrisii",
                  "Rhodochortontenue",
                  "Schizoporellajaponica",
                  "Sinelobusvanhaareni",
                  "Streblospiobenedicti",
                  "Telmatogetonjaponicus",
                  "Thalassiosirapunctigera",
                  "Tharyxsetigera",
                  "Torquigenerflavimaculosus",
                  "Xenostrobussecuris")

# Map: no-spaces code -> canonical with-spaces (matches alien_regions$species)
species_key <- setNames(species_list, gsub(" ", "", species_list, fixed = TRUE))

masked_in_dir  <- file.path(proj_dir, "masked")        
masked_out_dir <- file.path(masked_in_dir, "alien")            
dir.create(masked_out_dir, recursive = TRUE, showWarnings = FALSE)

files <- list.files(
  masked_in_dir,
  pattern = "_EMwmeanByTSS_.*\\.(tif|tiff)$",  # scenario NOT in filename anymore
  full.names = TRUE,
  ignore.case = TRUE
)
if (!length(files)) {
  cat("⚠️ No EMwmeanByTSS rasters found in:", masked_in_dir, "\n")
}

for (f in files) {
  base <- basename(f)
  
  # Extract species code (handles optional 'MASKED_' prefix)
  species_no_spaces <- sub("^(MASKED_)?([^_]+)_EMwmeanByTSS.*$", "\\2",
                           file_path_sans_ext(base))
  
  if (!species_no_spaces %in% names(species_key)) {
    cat("  ⚠️ Unknown species code in filename:", base, "\n")
    next
  }
  species_name <- species_key[[species_no_spaces]]
  cat("  🔄 MEOW-masking:", species_name, "\n")
  
  out_file <- file.path(masked_out_dir, paste0("ALIENMASK_", base))
  
  r_suit <- tryCatch(rast(f), error = function(e) NULL)
  if (is.null(r_suit)) {
    cat("    ⚠️ Failed to read raster:", base, "\n")
    next
  }
  
  # Regions for this species from CSV
  rows <- alien_regions[alien_regions$species == species_name, , drop = FALSE]
  if (!nrow(rows)) {
    cat("    ⚠️ No alien-region row for species in CSV:", species_name, "\n")
    next
  }
  
  # Collect ecoregions (supports multiple rows and ; or , separators)
  regions_raw <- rows$ecoregions
  regions <- unlist(strsplit(paste(regions_raw, collapse = ";"), "[;,]"))
  regions <- trimws(regions)
  regions <- regions[regions != ""]
  if (any(tolower(regions) == "all_metro_europe")) regions <- all_metro_ecoregions
  
  # Subset MEOW by ECOREGION
  meow_mask_vec <- subset(meow, meow$ECOREGION %in% regions)
  if (!nrow(meow_mask_vec)) {
    cat("    ⚠️ No matching MEOW ecoregions for species:", species_name, "\n")
    next
  }
  
  # Rasterize MEOW subset to the *same grid* as the raster
  mask_r <- rasterize(meow_mask_vec, r_suit, field = 1, background = NA)
  
  # Keep values only inside allowed ecoregions (mask keeps non-NA)
  r_suit_alien <- mask(r_suit, mask_r)
  
  writeRaster(r_suit_alien, out_file, overwrite = TRUE)
  cat("    ✅ Saved:", out_file, "\n")
}


# ===================================================
# 3) NORMALIZATION  INDIVIDUAL MAP 0 - 1000 to 0 - 1
# outputs: ALIENMASK_MASKED_species_..._norm01.tif
# in folder: .../<sc>_proj/masked/alien/normalized
# ===================================================


suppressPackageStartupMessages(library(terra))
terraOptions(memfrac = 0.5)  # Use less RAM

# ------------------ SETTINGS ------------------
base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"
scenarios <- c("ssp126", "ssp245", "ssp585")
theoretical_min <- 0
theoretical_max <- 1000

# ------------------ LOOP OVER SCENARIOS -------
for (sc in scenarios) {
  
  in_dir  <- file.path(base_dir, paste0(sc, "_proj/masked/alien"))
  out_dir <- file.path(in_dir, "normalized")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  
  cat("\n--- Normalizing:", sc, "---\n")
  
  files <- list.files(in_dir, pattern = "\\.tif$", full.names = TRUE)
  # Exclude already normalized files
  files <- files[!grepl("_norm01\\.tif$", files)]
  
  if (length(files) == 0) {
    cat("⚠️ No .tif files found in", in_dir, "\n")
    next
  }
  
  for (f in files) {
    base <- basename(f)
    out_file <- file.path(out_dir, sub("\\.tif$", "_norm01.tif", base))
    
    cat("📄 Processing:", base, "\n")
    
    tryCatch({
      # Load raster
      r <- rast(f)
      
      # Normalize using terra's built-in operations (file-backed)
      r_norm <- (r - theoretical_min) / (theoretical_max - theoretical_min)
      r_norm <- clamp(r_norm, lower = 0, upper = 1)  # faster than subsetting
      
      # Write directly to disk in chunks
      writeRaster(r_norm, out_file, 
                  overwrite = TRUE,
                  gdal = c("COMPRESS=LZW", "TILED=YES"),
                  datatype = "FLT4S")  # 32-bit float is enough
      
      cat("✅ Saved:", basename(out_file), "\n")
      
      # Clean up
      rm(r, r_norm)
      gc(verbose = FALSE)
      
    }, error = function(e) {
      cat("❌ ERROR processing", base, ":", conditionMessage(e), "\n")
      gc(verbose = FALSE)
    })
  }
  
  # Clean up between scenarios
  tmpFiles(remove = TRUE)  # remove temp files
  gc()
}

cat("\n🎉 All done!\n")

# ===================================================
# STACK NORMALIZED MAPS (before any delta calculation)
# (produces mean suitability across species per pixel)
# outputs: stack_mean_norm01_<sc>.tif
# in folder: .../<sc>_proj/masked/alien/stacked_norm01
# ===================================================

# FOR CERTAIN SPECIES ONLY
suppressPackageStartupMessages(library(terra))
terraOptions(memfrac = 0.6)
base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"
scenarios <- c("current","ssp126", "ssp245", "ssp585")
# Define which species to stack (leave as NULL to stack all)
species_to_stack <- c("AcartiaAcanthacartiatonsa",
                  "Amphibalanusamphitrite",
                  "Amphibalanuseburneus",
                  "Amphibalanusimprovisus",
                  "ApionsomaApionsomamisakianum",
                  "Arcuatulasenhousia",
                  "Ascidiellaaspersa",
                  "Asparagopsisarmata",
                  "Asparagopsistaxiformis",
                  "Aureliasolida",
                  "Austrominiusmodestus",
                  "Balanustrigonus",
                  "Boccardiaproboscidea",
                  "Bonnemaisoniahamifera",
                  "Botrylloidesviolaceus",
                  "Bugulaneritina",
                  "Caprellamutica",
                  "Caprellascaura",
                  "Corambeobscura",
                  "Cordylophoracaspia",
                  "Corellaeumyota",
                  "Crepidulafornicata",
                  "Cutleriamultifida",
                  "Dasysiphoniajaponica",
                  "Ensisleei",
                  "Evadneanonyx",
                  "Fenestrulinadelicia",
                  "Fibrocapsajaponica",
                  "Ficopomatusenigmaticus",
                  "Gammarustigrinus",
                  "Gonionemusvertens",
                  "Haloajaponica",
                  "Haminellasolitaria",
                  "Hemigrapsustakanoi",
                  "Herdmaniamomus",
                  "Hydroideselegans",
                  "Juxtacribrilinamutabilis",
                  "Marenzelleriaarctia",
                  "Marenzellerianeglecta",
                  "Marenzelleriaviridis",
                  "Melanothamnusharveyi",
                  "Mnemiopsisleidyi",
                  "Monocorophiumacherusicum",
                  "Monocorophiumsextonae",
                  "Neogobiusmelanostomus",
                  "Oithonadavisae",
                  "Ostreopsisovata",
                  "Palaemonelegans",
                  "Paracerceissculpta",
                  "Perophorajaponica",
                  "Petricolariapholadiformis",
                  "Polydoracornuta",
                  "Polydorawebsteri",
                  "Polysiphoniabrodiei",
                  "Potamopyrgusantipodarum",
                  "Pseudocalanusacuspes",
                  "Pseudocalanusmimus",
                  "Pseudodiaptomusmarinus",
                  "Rangiacuneata",
                  "Rhithropanopeusharrisii",
                  "Rhodochortontenue",
                  "Schizoporellajaponica",
                  "Sinelobusvanhaareni",
                  "Streblospiobenedicti",
                  "Telmatogetonjaponicus",
                  "Thalassiosirapunctigera",
                  "Tharyxsetigera",
                  "Torquigenerflavimaculosus",
                  "Xenostrobussecuris")

for (sc in scenarios) {
  norm_dir  <- file.path(base_dir, paste0(sc, "_proj/masked/alien/normalized"))
  out_stack <- file.path(base_dir, paste0(sc, "_proj/masked/alien/stacked_norm01"))
  dir.create(out_stack, recursive = TRUE, showWarnings = FALSE)
  
  files_norm <- list.files(norm_dir, pattern = "_norm01\\.tif$", full.names = TRUE)
  if (!length(files_norm)) {
    cat("⚠️ No normalized rasters found for", sc, "in", norm_dir, "\n")
    next
  }
  
  # Filter for specific species if specified
  if (!is.null(species_to_stack)) {
    files_norm <- files_norm[sapply(files_norm, function(f) {
      parts <- strsplit(basename(f), "_")[[1]]
      species_name <- parts[3]
      species_name %in% species_to_stack
    })]
    
    if (!length(files_norm)) {
      cat("⚠️ No files found for specified species in", sc, "\n")
      next
    }
    cat("📋 Stacking", length(files_norm), "species\n")
  }
  
  cat("\n--- Building stacks for", sc, "---\n")
  S <- rast(files_norm)
  
  #  Mean stack
  mean_path <- file.path(out_stack, paste0("new_stack_mean_norm01_", sc, ".tif"))
  if (file.exists(mean_path)) file.remove(mean_path)  # DELETE FIRST
  mean_r <- mean(S, na.rm = TRUE)
  writeRaster(mean_r, mean_path, overwrite = TRUE)
  cat("✔ Wrote:", mean_path, "\n")
  
  rm(S, mean_r); gc()
}

# ===================================================
# DELTA MAPS FOR INDIVIDUAL SPECIES
# outputs: <species>_EMwmean..._<sc>_delta_norm01.tif
# in folder: .../<sc>_proj/masked/alien/deltas_norm01
# ===================================================

# ------------------ SETTINGS -
base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"
scenarios <- c("current", "ssp126", "ssp245", "ssp585")
norm_sub  <- "normalized"

# Output parent for aggregated deltas
out_dir_global <- file.path(base_dir, "changes_speciesmaps_norm01")
dir.create(out_dir_global, showWarnings = FALSE)

theoretical_min <- 0
theoretical_max <- 1000
agg_fun <- "mean"         # "mean" or "sum"
no_change_band <- 0.05    # white band for "no change"

# ------------------ HELPER FUNCTIONS ---
get_norm_files <- function(scen) {
  in_dir <- file.path(base_dir, paste0(scen, "_proj/masked/alien"), norm_sub)
  fs <- list.files(in_dir, pattern = "_norm01\\.tif$", full.names = TRUE)
  if (!length(fs)) stop("No normalized rasters in: ", in_dir)
  keys <- sub("_norm01\\.tif$", "", basename(fs))
  keys <- sub("^ALIENMASK_MASKED_", "", keys)
  setNames(fs, keys)
}

write_and_msg <- function(r, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeRaster(r, path, overwrite = TRUE)
  cat("✔ Wrote:", path, "\n")
}

# ------------------ LOAD STACKS --
lst <- lapply(scenarios, get_norm_files)
names(lst) <- scenarios

common_keys <- Reduce(intersect, lapply(lst, names))
lst <- lapply(lst, function(v) v[common_keys])

stacks <- lapply(lst, function(v) rast(unname(v)))

# Align geometries
for (sc in scenarios[-1]) {
  if (!compareGeom(stacks[[sc]], stacks[["current"]], stopOnError = FALSE)) {
    stacks[[sc]] <- project(stacks[[sc]], stacks[["current"]])
    cat("ℹ Reprojected:", sc, "to current geometry\n")
  }
}

# ------------------ PER-SPECIES DELTAS --
cur_stack <- stacks[["current"]]

cur_files <- get_norm_files("current")

for (sc in setdiff(scenarios, "current")) {
  fut_files <- get_norm_files(sc)
  
  # match species across scenarios
  common_keys <- intersect(names(cur_files), names(fut_files))
  if (!length(common_keys)) {
    cat("No common species; skipping", sc, "\n"); next
  }
  cur_vec <- cur_files[common_keys]
  fut_vec <- fut_files[common_keys]
  
  cat("\n--- Writing individual deltas for", sc, "---\n")
  out_dir_species <- file.path(base_dir, paste0(sc, "_proj/masked/alien/deltas_norm01"))
  dir.create(out_dir_species, recursive = TRUE, showWarnings = FALSE)
  
  for (sp in common_keys) {
    r_cur <- rast(cur_vec[[sp]])
    r_fut <- rast(fut_vec[[sp]])
    
    # align geometries if needed
    if (!compareGeom(r_fut, r_cur, stopOnError = FALSE)) {
      r_fut <- project(r_fut, r_cur)
    }
    
    delta <- r_fut - r_cur  # [-1, 1] in normalized units
    out_sp <- file.path(out_dir_species, paste0("ALIENMASK_MASKED_", sp, "_", sc, "_delta_norm01.tif"))
    writeRaster(delta, out_sp, overwrite = TRUE)
    cat("  ✔", sp, "\n")
    
    rm(r_cur, r_fut, delta); gc()
  }
}



# ===================================================
# AGGREGATE DELTA MAPS 
# outputs: delta_mean_<sc>_vs_current_norm01.tif; delta_mean_<sc>_vs_current_norm01_trinary.tif
# in folder: .../continuous_changes_norm01
# ===================================================


agg_fun <- "mean"        # or "sum"
no_change_band <- 0.05
out_dir_global <- file.path(base_dir, "continuous_changes_norm01")
dir.create(out_dir_global, showWarnings = FALSE)

for (sc in setdiff(scenarios, "current")) {
  delta_dir <- file.path(base_dir, paste0(sc, "_proj/masked/alien/deltas_norm01"))
  delta_paths <- list.files(delta_dir, pattern = "_delta_norm01\\.tif$", full.names = TRUE)
  if (!length(delta_paths)) {
    cat("No per-species deltas found for", sc, "\n"); next
  }
  
  cat("\n--- Aggregating deltas for", sc, "(streamed) ---\n")
  delta_stack <- rast(delta_paths)
  
  out_agg <- file.path(out_dir_global, paste0("delta_", agg_fun, "_", sc, "_vs_current_norm01.tif"))
  if (agg_fun == "mean") {
    delta_agg <- mean(delta_stack, na.rm = TRUE, filename = out_agg, overwrite = TRUE)
  } else {
    delta_agg <- sum(delta_stack,  na.rm = TRUE, filename = out_agg, overwrite = TRUE)
  }
  cat("✔ Wrote aggregate:", out_agg, "\n")
  
  # Optional trinary (white band ±0.05)
  M <- rbind(
    c(-Inf, -no_change_band, -1),
    c(-no_change_band,  no_change_band, 0),
    c( no_change_band,  Inf, 1)
  )
  out_tri <- sub("\\.tif$", "_trinary.tif", out_agg)
  classify(delta_agg, M, filename = out_tri, overwrite = TRUE)
  cat("✔ Wrote trinary:", out_tri, "\n")
  
  rm(delta_stack, delta_agg); gc()
}

# ===================================================
# TRANSFORM EMca FILES FROM 0-1000 TO 0-1 SCALE
# outputs: .../EMca_normalized/<sc>/_EMca...tif
# ===================================================

library(terra)

# Directories
emca_base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/EMca"
output_base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/EMca/EMca_normalized"

# Create output directory
dir.create(output_base_dir, recursive = TRUE, showWarnings = FALSE)

# Scenarios to process
scenarios <- c("current","ssp126","ssp245","ssp585")  # Add "ssp245" when available

cat("\n=== Transforming EMca files from 0-1000 to 0-1 ===\n")

for (scenario in scenarios) {

  cat(sprintf("\nProcessing scenario: %s\n", scenario))

  # Input and output directories
  input_dir <- file.path(emca_base_dir, scenario)
  output_dir <- file.path(output_base_dir, scenario)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Find all EMca files in the scenario directory
  emca_files <- list.files(input_dir,
                           pattern = "_EMca.*\\.tif$",
                           full.names = TRUE)

  if (length(emca_files) == 0) {
    cat(sprintf("  ⚠️ No EMca files found in %s\n", input_dir))
    next
  }

  cat(sprintf("  Found %d EMca file(s)\n", length(emca_files)))

  # Process each file
  for (emca_file in emca_files) {

    filename <- basename(emca_file)
    output_file <- file.path(output_dir, filename)

    # Check if output file already exists
    if (file.exists(output_file)) {
      cat(sprintf("  ⏭️  Skipping (already exists): %s\n", filename))
      next
    }

    cat(sprintf("  Processing: %s\n", filename))

    # Read the raster
    r_emca <- rast(emca_file)

    # Check the value range
    emca_range <- global(r_emca, range, na.rm = TRUE)
    cat(sprintf("    Original range: [%.3f, %.3f]\n",
                emca_range[1, 1], emca_range[2, 1]))

    # Transform to 0-1 scale
    r_emca_normalized <- r_emca / 1000

    # Verify new range
    new_range <- global(r_emca_normalized, range, na.rm = TRUE)
    cat(sprintf("    Normalized range: [%.3f, %.3f]\n",
                new_range[1, 1], new_range[2, 1]))

    # Save the normalized raster
    writeRaster(r_emca_normalized, output_file, overwrite = TRUE)

    cat(sprintf("    ✅ Saved: %s\n", output_file))
  }
}

cat("\n✅ All EMca files transformed successfully!\n")
cat(sprintf("Output directory: %s\n", output_base_dir))

# ===================================================
# ECOREGION-SPECIFIC ANALYSIS
# Analyze species turnover, gains/losses per MEOW ecoregion
# outputs: 
# in folder: 
# ===================================================
base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"
scenarios <- c("current", "ssp126", "ssp245", "ssp585")
meow_path <- "C:/biomod2_git/MEOW_FINAL/MEOW/meow_ecos.shp"
out_dir <- file.path(base_dir, "ecoregion_analysis")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Load MEOW ecoregions
meow <- vect(meow_path)
meow_sf <- st_as_sf(meow)  # for easier plotting

# European ecoregions (from your script)
euro_ecoregions <- c(
  "South European Atlantic Shelf", "North Sea", "Southern Norway",
  "Northern Norway and Finnmark", "Baltic Sea", "Celtic Seas",
  "Adriatic Sea", "Ionian Sea", "Aegean Sea", "Alboran Sea",
  "Western Mediterranean", "Levantine Sea", "Tunisian Plateau/Gulf of Sidra",
  "Faroe Plateau", "North and East Iceland", "North and East Barents Sea",
  "South and West Iceland", "Black Sea"
)

meow_euro <- subset(meow, meow$ECOREGION %in% euro_ecoregions)
meow_euro_sf <- st_as_sf(meow_euro)

# 3) MEAN SUITABILITY CHANGE PER ECOREGION
# Calculate mean delta across all species within each ecoregion
ecoregion_delta_results <- list()

for (sc in setdiff(scenarios, "current")) {
  delta_dir <- file.path(base_dir, paste0(sc, "_proj/masked/alien/deltas_norm01"))
  delta_files <- list.files(delta_dir, pattern = "_delta_norm01\\.tif$", full.names = TRUE)
  
  if (!length(delta_files)) next
  
  cat("\n--- Calculating mean delta per ecoregion for", sc, "---\n")
  
  # Stack all deltas
  delta_stack <- rast(delta_files)
  
  # Mean across species
  mean_delta <- mean(delta_stack, na.rm = TRUE)
  
  for (i in 1:nrow(meow_euro)) {
    ecoregion_name <- meow_euro$ECOREGION[i]
    ecoregion_geom <- meow_euro[i]
    
    # Crop and mask to ecoregion
    delta_crop <- tryCatch({
      crop(mean_delta, ecoregion_geom, mask = TRUE)
    }, error = function(e) NULL)
    
    if (is.null(delta_crop)) next
    
    # Calculate area-weighted mean
    area_km2 <- cellSize(delta_crop, unit = "km")
    weighted_mean_delta <- global(delta_crop * area_km2, "sum", na.rm = TRUE)[1,1] / 
      global(area_km2, "sum", na.rm = TRUE)[1,1]
    
    # Additional stats
    stats <- global(delta_crop, fun = c("mean", "min", "max", "sd"), na.rm = TRUE)
    
    ecoregion_delta_results[[paste(sc, ecoregion_name, sep = "_")]] <- data.frame(
      scenario = sc,
      ecoregion = ecoregion_name,
      mean_delta = stats$mean,
      weighted_mean_delta = weighted_mean_delta,
      min_delta = stats$min,
      max_delta = stats$max,
      sd_delta = stats$sd
    )
    
    cat("  ✔", ecoregion_name, ": weighted mean =", round(weighted_mean_delta, 4), "\n")
  }
}

ecoregion_delta_df <- bind_rows(ecoregion_delta_results)
write.csv(ecoregion_delta_df, file.path(out_dir, "ecoregion_mean_delta.csv"), row.names = FALSE)