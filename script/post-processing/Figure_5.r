library(terra)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(dplyr)
library(patchwork)
library(ggpubr)

base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"

# European extent
xlim_eu <- c(-28, 70)
ylim_eu <- c(28, 83)

# Load world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# Future scenarios to compare
future_scenarios <- c("ssp126", "ssp245", "ssp585")

# Create output directory
plot_dir <- file.path(base_dir, "stacked_current_and_differences_plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

# STEP 1: Load current stacked suitability
current_suit_path <- file.path(base_dir, "current_proj/masked/alien/stacked_norm01",
                               "new_stack_mean_norm01_current.tif")
r_current_suit <- rast(current_suit_path)

# STEP 2: Skip current suitability map - only showing changes

# STEP 3: Calculate differences for all scenarios and check ranges
all_diff_ranges <- list()

for (i in 1:length(future_scenarios)) {
  scenario_name <- future_scenarios[i]

  # Load future stacked suitability
  future_suit_path <- file.path(base_dir, paste0(scenario_name, "_proj/masked/alien/stacked_norm01"),
                                paste0("new_stack_mean_norm01_", scenario_name, ".tif"))
  r_future_suit <- rast(future_suit_path)

  # Calculate difference: future - current
  r_diff <- r_future_suit - r_current_suit

  # Get range
  diff_values <- values(r_diff, na.rm = TRUE)
  all_diff_ranges[[scenario_name]] <- list(
    min = min(diff_values, na.rm = TRUE),
    max = max(diff_values, na.rm = TRUE),
    mean = mean(diff_values, na.rm = TRUE),
    median = median(diff_values, na.rm = TRUE),
    q05 = quantile(diff_values, 0.05, na.rm = TRUE),
    q95 = quantile(diff_values, 0.95, na.rm = TRUE)
  )

  rm(r_future_suit, r_diff)
  gc(verbose = FALSE)
}

# Display ranges
for (scenario_name in names(all_diff_ranges)) {
  stats <- all_diff_ranges[[scenario_name]]
  scenario_label <- toupper(gsub("ssp", "SSP", scenario_name))
  scenario_label <- gsub("(\\d)(\\d)(\\d)", "\\1-\\2.\\3", scenario_label)

  cat(sprintf("\n%s:\n", scenario_label))
  cat(sprintf("  Min:       %7.4f\n", stats$min))
  cat(sprintf("  5th pctl:  %7.4f\n", stats$q05))
  cat(sprintf("  Median:    %7.4f\n", stats$median))
  cat(sprintf("  Mean:      %7.4f\n", stats$mean))
  cat(sprintf("  95th pctl: %7.4f\n", stats$q95))
  cat(sprintf("  Max:       %7.4f\n", stats$max))
}

# Overall range
all_mins <- sapply(all_diff_ranges, function(x) x$min)
all_maxs <- sapply(all_diff_ranges, function(x) x$max)
cat(sprintf("\nOVERALL RANGE: %7.4f to %7.4f\n", min(all_mins), max(all_maxs)))


# STEP 4: Create Panels 2-4 - Difference maps with categories
all_diff_plots <- list()
all_category_stats <- list()

for (i in 1:length(future_scenarios)) {
  scenario_name <- future_scenarios[i]

  cat(sprintf("Processing scenario: %s\n", scenario_name))

  # Load future stacked suitability
  future_suit_path <- file.path(base_dir, paste0(scenario_name, "_proj/masked/alien/stacked_norm01"),
                                paste0("new_stack_mean_norm01_", scenario_name, ".tif"))
  r_future_suit <- rast(future_suit_path)

  cat("  Loaded future suitability\n")

  # Calculate difference: future - current (positive = gain, negative = loss)
  r_diff <- r_future_suit - r_current_suit

  cat("  Calculated difference\n")

  # Convert to dataframe
  df_diff <- as.data.frame(r_diff, xy = TRUE)
  names(df_diff)[3] <- "difference"
  df_diff <- df_diff[!is.na(df_diff$difference), ]

  # Define all category levels based on actual data range (-0.11 to +0.27)
  all_levels <- c("Moderate decrease\n(< -0.10)",
                  "Slight decrease\n(-0.10 to -0.05)",
                  "No change\n(-0.05 to 0.05)",
                  "Slight increase\n(0.05 to 0.10)",
                  "Moderate increase\n(0.10 to 0.15)",
                  "Substantial increase\n(0.15 to 0.20)",
                  "Major increase\n(> 0.20)")

  # Classify into categories
  df_diff$change_cat <- cut(df_diff$difference,
                            breaks = c(-Inf, -0.10, -0.05, 0.05, 0.10, 0.15, 0.20, Inf),
                            labels = all_levels,
                            include.lowest = TRUE)

  # Ensure all levels are present in the factor (even if no data)
  df_diff$change_cat <- factor(df_diff$change_cat, levels = all_levels)

  cat("  Classified changes into categories\n")

  # Calculate statistics for each category
  total_pixels <- nrow(df_diff)
  category_counts <- table(df_diff$change_cat)
  category_percentages <- (category_counts / total_pixels) * 100

  # Store statistics
  all_category_stats[[scenario_name]] <- data.frame(
    Category = names(category_counts),
    Count = as.vector(category_counts),
    Percentage = as.vector(category_percentages)
  )

  # Format scenario label
  scenario_label <- toupper(gsub("ssp", "SSP", scenario_name))
  scenario_label <- gsub("(\\d)(\\d)(\\d)", "\\1-\\2.\\3", scenario_label)  # Format as SSP1-2.6

  dummy_df <- data.frame(
    x = rep(NA_real_, length(all_levels)),
    y = rep(NA_real_, length(all_levels)),
    change_cat = factor(all_levels, levels = all_levels)
  )
  # Create difference plot with categories
  p_diff <- ggplot() +
    geom_raster(data = df_diff, aes(x = x, y = y, fill = change_cat)) +
    geom_raster(data = dummy_df, aes(x = x, y = y, fill = change_cat)) +
    geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
    scale_fill_manual(
      values = c("Moderate decrease\n(< -0.10)" = "#2166AC",
                 "Slight decrease\n(-0.10 to -0.05)" = "#92C5DE",
                 "No change\n(-0.05 to 0.05)" = "white",
                 "Slight increase\n(0.05 to 0.10)" = "#FDDBC7",
                 "Moderate increase\n(0.10 to 0.15)" = "#F4A582",
                 "Substantial increase\n(0.15 to 0.20)" = "#D6604D",
                 "Major increase\n(> 0.20)" = "#B2182B"),
      na.value = "transparent",
      name = NULL,
      drop = FALSE,
      guide = guide_legend(
        title.position = "top",
        title.hjust = 0.5,
        direction = "vertical",
        label.position = "right",
        nrow = 7,
        byrow = TRUE,
        override.aes = list(color = NA)
      )
    ) +
    coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
    labs(title = paste0("Change in mean suitability (2100, ", scenario_label, ")")) +
    theme_minimal(base_size = 20) +
    theme(
      panel.background = element_rect(fill = "aliceblue"),
      panel.grid = element_line(color = "white", linewidth = 0.3),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      plot.title = element_text(face = "bold", size = 34, hjust = 0.5),
      legend.position = "right",
      legend.box = "vertical",
      legend.key.width = unit(1.5, "cm"),
      legend.key.height = unit(2.5, "cm"),
      legend.text = element_text(size = 26),
      legend.title = element_text(size = 28, face = "bold"),
      legend.key = element_rect(color = "black", linewidth = 0.3),
      legend.spacing.y = unit(0.8, "cm"),
      axis.title = element_blank(),
      axis.text = element_text(size = 22, color = "grey30"),
      plot.margin = margin(10, 10, 10, 10)
    )

  all_diff_plots[[i]] <- p_diff

  cat(sprintf("✅ Panel %d created for %s\n", i + 1, scenario_label))

  # Clean up
  rm(r_future_suit, r_diff, df_diff)
  gc(verbose = FALSE)
}

# Display category statistics for all scenarios
cat("\n========================================\n")
cat("CATEGORY STATISTICS BY SCENARIO\n")
cat("========================================\n")

for (scenario_name in names(all_category_stats)) {
  scenario_label <- toupper(gsub("ssp", "SSP", scenario_name))
  scenario_label <- gsub("(\\d)(\\d)(\\d)", "\\1-\\2.\\3", scenario_label)

  cat(sprintf("\n%s:\n", scenario_label))
  cat(sprintf("%-40s %12s %12s\n", "Category", "Pixels", "Percentage"))
  cat(strrep("-", 66), "\n")

  stats <- all_category_stats[[scenario_name]]
  for (j in 1:nrow(stats)) {
    # Clean category name for display (remove newlines)
    cat_name <- gsub("\n", " ", stats$Category[j])
    cat(sprintf("%-40s %12d %11.2f%%\n",
                cat_name,
                stats$Count[j],
                stats$Percentage[j]))
  }
  cat(sprintf("%-40s %12d %11.2f%%\n", "TOTAL", sum(stats$Count), sum(stats$Percentage)))
}

cat("\n========================================\n\n")

# STEP 5: Combine 3 change panels in a single column with shared legend below
cat("\nCreating single-column layout with 3 change maps and legend below...\n")

# Remove legends from diff plots (we'll add a shared one later)
all_diff_plots_nolegend <- lapply(all_diff_plots, function(p) p + theme(legend.position = "none"))

# Extract the shared legend from one of the diff plots
shared_legend <- get_legend(all_diff_plots[[1]] +
                            guides(fill = guide_legend(
                              direction = "horizontal",
                              ncol = 7,
                              label.position = "bottom",
                              keywidth = unit(1.5, "cm"),
                              keyheight = unit(1.2, "cm"),
                              override.aes = list(size = 1)
                            )) +
                            theme(
                              legend.text = element_text(size = 26),
                              legend.spacing.x = unit(0.4, "cm"),
                              legend.key.size = unit(1.2, "cm")
                            ))

# Combine plots with spacing and legend below using ggarrange
combined_plot <- ggarrange(all_diff_plots_nolegend[[1]],
                            all_diff_plots_nolegend[[2]],
                            all_diff_plots_nolegend[[3]],
                            shared_legend,
                            ncol = 1, nrow = 4,
                            heights = c(1, 1, 1, 0.15),
                            labels = c("a", "b", "c", ""),
                            font.label = list(size = 40, face = "bold"))

# Save plot (single-column layout with legend below)
out_file <- file.path(plot_dir, "new_stacked_3scenarios_differences_new_vertical.png")
ggsave(out_file, combined_plot,
       width = 24, height = 42, dpi = 300, bg = "white")

cat(sprintf("✅ Created single-column panel figure: %s\n", out_file))

# Clean up
rm(r_current_suit, all_diff_plots, combined_plot)
gc()

cat("\n========================================\n")
cat("✅ All plots saved in:", plot_dir, "\n")
cat("========================================\n")