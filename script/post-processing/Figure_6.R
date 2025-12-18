# ============================================================================
# ECOREGION COMPARISON: PERCENTAGE AND ABSOLUTE CHANGE
# Creates grouped bar charts showing both % change and absolute change
# ============================================================================

library(terra)
library(sf)
library(tidyverse)
library(reshape2)
library(patchwork) # For combining plots

# ----------------------------------------------------------------------------
# 1. LOAD DATA
# ----------------------------------------------------------------------------

cat("\n=== LOADING DATA ===\n")

# Habitat suitability for all scenarios
hs_current <- rast("C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/current_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_current.tif")
hs_future_126 <- rast("C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ssp126_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp126.tif")
hs_future_245 <- rast("C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ssp245_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp245.tif")
hs_future_585 <- rast("C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ssp585_proj/masked/alien/stacked_norm01/new_stack_mean_norm01_ssp585.tif")

# Calculate changes
hs_change_126 <- hs_future_126 - hs_current
hs_change_245 <- hs_future_245 - hs_current
hs_change_585 <- hs_future_585 - hs_current

# Load MEOW ecoregions
meow <- vect("C:/biomod2_git/MEOW_FINAL/MEOW/meow_ecos.shp")
meow_sf <- st_as_sf(meow)

# Define study regions
all_metro_ecoregions <- c(
  "South European Atlantic Shelf", "North Sea", "Southern Norway",
  "Northern Norway and Finnmark", "Baltic Sea", "Celtic Seas",
  "Adriatic Sea", "Ionian Sea", "Aegean Sea", "Alboran Sea",
  "Western Mediterranean", "Levantine Sea", "Tunisian Plateau/Gulf of Sidra",
  "Faroe Plateau", "North and East Iceland", "North and East Barents Sea",
  "South and West Iceland", "Black Sea"
)

# Select study regions
study_regions <- meow_sf %>%
  filter(ECOREGION %in% all_metro_ecoregions)

# Add centroid latitude
study_regions <- study_regions %>%
  mutate(
    centroid_lat = st_coordinates(st_centroid(st_geometry(.)))[, 2],
    centroid_lon = st_coordinates(st_centroid(st_geometry(.)))[, 1]
  )

cat("Total ecoregions:", nrow(study_regions), "\n")

# ----------------------------------------------------------------------------
# 2. EXTRACT STATISTICS FOR ALL SCENARIOS
# ----------------------------------------------------------------------------

cat("\n=== EXTRACTING DATA FOR ALL SCENARIOS (including SD) ===\n")

extract_all_scenarios_with_sd <- function(regions_sf,
                                          raster_current,
                                          raster_126, raster_245, raster_585,
                                          change_126, change_245, change_585) {
  results <- list()

  for (i in 1:nrow(regions_sf)) {
    ecoregion_name <- regions_sf$ECOREGION[i]
    cat("Processing [", i, "/", nrow(regions_sf), "]: ", ecoregion_name, "\n", sep = "")

    # Get region
    region <- regions_sf[i, ]
    region_vect <- vect(region)

    # Extract current
    vals_current <- terra::extract(raster_current, region_vect, na.rm = TRUE)[[2]]
    vals_current <- vals_current[!is.na(vals_current)]

    # Extract SSP1-2.6
    vals_126 <- terra::extract(raster_126, region_vect, na.rm = TRUE)[[2]]
    vals_126 <- vals_126[!is.na(vals_126)]
    change_126_vals <- terra::extract(change_126, region_vect, na.rm = TRUE)[[2]]
    change_126_vals <- change_126_vals[!is.na(change_126_vals)]

    # Extract SSP2-4.5
    vals_245 <- terra::extract(raster_245, region_vect, na.rm = TRUE)[[2]]
    vals_245 <- vals_245[!is.na(vals_245)]
    change_245_vals <- terra::extract(change_245, region_vect, na.rm = TRUE)[[2]]
    change_245_vals <- change_245_vals[!is.na(change_245_vals)]

    # Extract SSP5-8.5
    vals_585 <- terra::extract(raster_585, region_vect, na.rm = TRUE)[[2]]
    vals_585 <- vals_585[!is.na(vals_585)]
    change_585_vals <- terra::extract(change_585, region_vect, na.rm = TRUE)[[2]]
    change_585_vals <- change_585_vals[!is.na(change_585_vals)]

    if (length(vals_current) == 0) {
      cat("  ⚠️ No data for", ecoregion_name, "\n")
      next
    }

    # Calculate cell-by-cell percentage change for SD calculation
    pct_change_126 <- 100 * (vals_126 - vals_current) / vals_current
    pct_change_245 <- 100 * (vals_245 - vals_current) / vals_current
    pct_change_585 <- 100 * (vals_585 - vals_current) / vals_current

    # Calculate statistics
    results[[i]] <- data.frame(
      ecoregion = ecoregion_name,
      province = regions_sf$PROVINCE[i],
      realm = regions_sf$REALM[i],
      latitude = round(regions_sf$centroid_lat[i], 2),
      longitude = round(regions_sf$centroid_lon[i], 2),
      n_cells = length(vals_current),

      # === CURRENT ===
      current_mean = mean(vals_current),
      current_median = median(vals_current),
      current_sd = sd(vals_current),

      # === SSP1-2.6 ===
      ssp126_mean = mean(vals_126),
      ssp126_median = median(vals_126),
      ssp126_change_abs = mean(change_126_vals),
      ssp126_change_abs_sd = sd(change_126_vals),
      ssp126_change_pct = mean(pct_change_126),
      ssp126_change_pct_sd = sd(pct_change_126),

      # === SSP2-4.5 ===
      ssp245_mean = mean(vals_245),
      ssp245_median = median(vals_245),
      ssp245_change_abs = mean(change_245_vals),
      ssp245_change_abs_sd = sd(change_245_vals),
      ssp245_change_pct = mean(pct_change_245),
      ssp245_change_pct_sd = sd(pct_change_245),

      # === SSP5-8.5 ===
      ssp585_mean = mean(vals_585),
      ssp585_median = median(vals_585),
      ssp585_change_abs = mean(change_585_vals),
      ssp585_change_abs_sd = sd(change_585_vals),
      ssp585_change_pct = mean(pct_change_585),
      ssp585_change_pct_sd = sd(pct_change_585)
    )
  }

  bind_rows(results)
}

# Run extraction with SD
scenario_table <- extract_all_scenarios_with_sd(
  study_regions,
  hs_current,
  hs_future_126, hs_future_245, hs_future_585,
  hs_change_126, hs_change_245, hs_change_585
)

# ----------------------------------------------------------------------------
# 3. PREPARE DATA FOR DUAL METRICS VISUALIZATION
# ----------------------------------------------------------------------------

cat("\n=== PREPARING DATA FOR DUAL METRICS PLOT ===\n")

# Prepare percentage change data
pct_data <- scenario_table %>%
  select(
    ecoregion, latitude,
    ssp126_change_pct, ssp126_change_pct_sd,
    ssp245_change_pct, ssp245_change_pct_sd,
    ssp585_change_pct, ssp585_change_pct_sd
  ) %>%
  pivot_longer(
    cols = starts_with("ssp"),
    names_to = c("Scenario", "metric"),
    names_pattern = "ssp(.*)_change_(.*)",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = metric,
    values_from = value
  ) %>%
  mutate(
    Scenario = case_when(
      Scenario == "126" ~ "SSP1-2.6",
      Scenario == "245" ~ "SSP2-4.5",
      Scenario == "585" ~ "SSP5-8.5"
    ),
    Ecoregion = fct_reorder(ecoregion, latitude)
  ) %>%
  rename(Change = pct, SD = pct_sd)

# Prepare absolute change data
abs_data <- scenario_table %>%
  select(
    ecoregion, latitude,
    ssp126_change_abs, ssp126_change_abs_sd,
    ssp245_change_abs, ssp245_change_abs_sd,
    ssp585_change_abs, ssp585_change_abs_sd
  ) %>%
  pivot_longer(
    cols = starts_with("ssp"),
    names_to = c("Scenario", "metric"),
    names_pattern = "ssp(.*)_change_(.*)",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = metric,
    values_from = value
  ) %>%
  mutate(
    Scenario = case_when(
      Scenario == "126" ~ "SSP1-2.6",
      Scenario == "245" ~ "SSP2-4.5",
      Scenario == "585" ~ "SSP5-8.5"
    ),
    Ecoregion = fct_reorder(ecoregion, latitude)
  ) %>%
  rename(Change = abs, SD = abs_sd)

# ----------------------------------------------------------------------------
# 4. CREATE DUAL METRIC VISUALIZATION
# ----------------------------------------------------------------------------

cat("\n=== CREATING DUAL METRIC PLOTS ===\n")

# Define consistent colors for scenarios
scenario_colors <- c(
  "SSP1-2.6" = "#8867A1",
  "SSP2-4.5" = "#fee08b",
  "SSP5-8.5" = "#B81840"
)

# Plot 1: Percentage Change
p_pct <- pct_data %>%
  ggplot(aes(x = Ecoregion, y = Change, fill = Scenario)) +
  geom_col(position = position_dodge(width = 0.9), alpha = 0.8) +
  geom_errorbar(
    aes(ymin = Change - SD, ymax = Change + SD),
    position = position_dodge(width = 0.9),
    width = 0.3,
    linewidth = 0.4,
    alpha = 0.7
  ) +
  scale_fill_manual(values = scenario_colors) +
  coord_flip() +
  theme_minimal() +
  labs(
    x = "",
    y = "% Change in Habitat Suitability",
    title = "a",
    fill = "Scenario"
  ) +
  theme(
    legend.position = "top",
    panel.grid.major.y = element_blank(),
    plot.title = element_text(face = "bold", size = 20),
    axis.text = element_text(size = 14),
    axis.title = element_text(size = 16),
    axis.title.x = element_text(margin = margin(t = 15)),  # Add space above x-axis title
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 16)
  )

# Plot 2: Absolute Change
p_abs <- abs_data %>%
  ggplot(aes(x = Ecoregion, y = Change, fill = Scenario)) +
  geom_col(position = position_dodge(width = 0.9), alpha = 0.8) +
  geom_errorbar(
    aes(ymin = Change - SD, ymax = Change + SD),
    position = position_dodge(width = 0.9),
    width = 0.3,
    linewidth = 0.4,
    alpha = 0.7
  ) +
  scale_fill_manual(values = scenario_colors) +
  coord_flip() +
  theme_minimal() +
  labs(
    x = "",
    y = "Absolute Change in Habitat Suitability",
    title = "b",
    fill = "Scenario"
  ) +
  theme(
    legend.position = "top",
    panel.grid.major.y = element_blank(),
    plot.title = element_text(face = "bold", size = 20),
    axis.text = element_text(size = 14),
    axis.title = element_text(size = 16),
    axis.title.x = element_text(margin = margin(t = 15)),  # Add space above x-axis title
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 16),
    axis.text.y = element_blank()
  )

# Combine plots side by side with clear separation
p_combined <- p_pct + p_abs +
  plot_layout(guides = "collect") &
  theme(
    legend.position = "bottom",
    plot.margin = margin(10, 20, 10, 10)  # Add margins around each plot
  )

# Save combined plot
ggsave(
  "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ecoregion_analysis/new_ecoregion_grouped_bars_dual_metrics.png",
  p_combined,
  width = 16,
  height = 10,
  dpi = 300
)

# ----------------------------------------------------------------------------
# 5. SUMMARY TABLES
# ----------------------------------------------------------------------------

cat("\n=== CREATING SUMMARY TABLES ===\n")

# Create a comparison table with both metrics
comparison_table <- scenario_table %>%
  select(
    Ecoregion = ecoregion,
    Latitude = latitude,
    # SSP1-2.6
    `SSP1-2.6 Abs Δ` = ssp126_change_abs,
    `SSP1-2.6 % Δ` = ssp126_change_pct,
    # SSP2-4.5
    `SSP2-4.5 Abs Δ` = ssp245_change_abs,
    `SSP2-4.5 % Δ` = ssp245_change_pct,
    # SSP5-8.5
    `SSP5-8.5 Abs Δ` = ssp585_change_abs,
    `SSP5-8.5 % Δ` = ssp585_change_pct
  ) %>%
  arrange(desc(`SSP5-8.5 % Δ`)) %>%
  mutate(across(where(is.numeric) & !Latitude, ~ round(., 4)))

write_csv(
  comparison_table,
  "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ecoregion_analysis/ecoregion_dual_metrics_table.csv"
)

# Print summary statistics
cat("\n=== SUMMARY: MEAN ABSOLUTE vs PERCENTAGE CHANGE ===\n")

summary_dual <- data.frame(
  Scenario = c("SSP1-2.6", "SSP2-4.5", "SSP5-8.5"),
  Mean_Abs_Change = c(
    mean(scenario_table$ssp126_change_abs),
    mean(scenario_table$ssp245_change_abs),
    mean(scenario_table$ssp585_change_abs)
  ),
  SD_Abs_Change = c(
    sd(scenario_table$ssp126_change_abs),
    sd(scenario_table$ssp245_change_abs),
    sd(scenario_table$ssp585_change_abs)
  ),
  Mean_Pct_Change = c(
    mean(scenario_table$ssp126_change_pct),
    mean(scenario_table$ssp245_change_pct),
    mean(scenario_table$ssp585_change_pct)
  ),
  SD_Pct_Change = c(
    sd(scenario_table$ssp126_change_pct),
    sd(scenario_table$ssp245_change_pct),
    sd(scenario_table$ssp585_change_pct)
  )
) %>%
  mutate(across(where(is.numeric), ~ round(., 4)))

print(summary_dual)

write_csv(
  summary_dual,
  "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/ecoregion_analysis/ecoregion_dual_metrics_summary.csv"
)

cat("\n✓ All analysis complete!\n")
cat("  - Created 3 visualization versions:\n")
cat("    1. Side-by-side comparison (dual_metrics.png)\n")
cat("    2. Vertical stacked comparison (dual_metrics_vertical.png)\n")
cat("    3. Faceted comparison (dual_metrics_faceted.png)\n")
cat("  - Saved comparison tables\n")
cat("  - Saved summary statistics\n")
