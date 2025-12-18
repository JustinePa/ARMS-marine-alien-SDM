library(terra)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(dplyr)
library(patchwork)

emcv_base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX/EMcv"
base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"

# European extent
xlim_eu <- c(-28, 70)
ylim_eu <- c(28, 83)

# Load world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# Target species (list of two species)
species_list <- list(
  list(code = "Crepidulafornicata", name = "Crepidula fornicata"),
  list(code = "AcartiaAcanthacartiatonsa", name = "Acartia Acanthacartia tonsa")
)

# Suitability threshold to define "suitable"
suitability_threshold <- 0.5

# Create output directory
plot_dir <- file.path(emcv_base_dir, "species_plots_change_with_transition")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

# We need current and ssp245 scenarios
scenarios_needed <- c("current", "ssp245")

# Initialize list to store all plots
all_plots <- list()

# Loop through each species
for (spp_idx in seq_along(species_list)) {
  species_code <- species_list[[spp_idx]]$code
  species_name <- species_list[[spp_idx]]$name

  cat(sprintf("\n=== Processing species %d/%d: %s ===\n", spp_idx, length(species_list), species_name))

  # Load data for both scenarios
  rasters <- list()

  for (scenario_name in scenarios_needed) {

    cat(sprintf("Loading data for: %s\n", scenario_name))

    # Paths
    masked_emcv_dir <- file.path(emcv_base_dir, scenario_name, "masked_emcv_alien")
    masked_suit_dir <- file.path(base_dir, paste0(scenario_name, "_proj/masked/alien/normalized"))

    # Find files
    emcv_file <- list.files(masked_emcv_dir,
                            pattern = paste0("ALIENMASK_", species_code, "_EMcvByTSS.*\\.tif$"),
                            full.names = TRUE)

    suit_file <- list.files(masked_suit_dir,
                            pattern = paste0("ALIENMASK_MASKED_", species_code, ".*norm01\\.tif$"),
                            full.names = TRUE)

    if (length(emcv_file) == 0 || length(suit_file) == 0) {
      stop(paste("  ⚠️ Files not found for", scenario_name))
    }

    # Read rasters
    r_suit <- rast(suit_file[1])
    r_emcv <- rast(emcv_file[1])
    r_cv <- r_emcv / 100

    # Store rasters
    rasters[[scenario_name]] <- list(
      suit = r_suit,
      cv = r_cv
    )
  }

  # Get current and future suitability
  r_suit_current <- rasters[["current"]]$suit
  r_suit_ssp245 <- rasters[["ssp245"]]$suit

  # Panel 1: Discrete Difference Map (ssp245 - current)
  r_diff <- r_suit_ssp245 - r_suit_current

  # Calculate difference statistics
  diff_stats <- global(r_diff, quantile, probs = c(0.05, 0.95), na.rm = TRUE)
  diff_range <- c(diff_stats[1, 1], diff_stats[2, 1])
  cat(sprintf("  Difference range (5th-95th percentile): [%.3f, %.3f]\n",
              diff_range[1], diff_range[2]))

  # Panel 2: Suitability Transition Map
  # Classify areas based on current and future suitability
  # 0 = Remains unsuitable (current < 0.5, future < 0.5)
  # 1 = Becomes suitable (current < 0.5, future >= 0.5)
  # 2 = Remains suitable (current >= 0.5, future >= 0.5)
  # 3 = Becomes unsuitable (current >= 0.5, future < 0.5)

  r_transition <- ifel(
    r_suit_current < suitability_threshold & r_suit_ssp245 < suitability_threshold,
    0,  # Remains unsuitable
    ifel(
      r_suit_current < suitability_threshold & r_suit_ssp245 >= suitability_threshold,
      1,  # Becomes suitable
      ifel(
        r_suit_current >= suitability_threshold & r_suit_ssp245 >= suitability_threshold,
        2,  # Remains suitable
        3   # Becomes unsuitable
      )
    )
  )

  # Calculate transition statistics
  transition_freq <- freq(r_transition)
  cat("  Transition statistics:\n")
  print(transition_freq)

  # Convert to dataframes
  cat("  Converting rasters to dataframes...\n")

  # Panel 1: Difference map
  df_diff <- as.data.frame(r_diff, xy = TRUE)
  names(df_diff)[3] <- "difference"
  df_diff <- df_diff[!is.na(df_diff$difference), ]

  # Classify into seven categories for discrete map
  df_diff$change_cat <- cut(df_diff$difference,
                            breaks = c(-Inf, -0.15, -0.10, -0.05, 0.05, 0.10, 0.15, Inf),
                            labels = c("Substantial decrease\n(< -0.15)",
                                       "Moderate decrease\n(-0.15 to -0.10)",
                                       "Slight decrease\n(-0.10 to -0.05)",
                                       "No change\n(-0.05 to 0.05)",
                                       "Slight increase\n(0.05 to 0.10)",
                                       "Moderate increase\n(0.10 to 0.15)",
                                       "Substantial increase\n(> 0.15)"),
                            include.lowest = TRUE)

  # Panel 2: Transition map
  df_transition <- as.data.frame(r_transition, xy = TRUE)
  names(df_transition)[3] <- "transition"
  df_transition <- df_transition[!is.na(df_transition$transition), ]

  # Create factor with labels
  df_transition$transition_cat <- factor(df_transition$transition,
                                         levels = c(0, 1, 2, 3),
                                         labels = c("Remains unsuitable\n(S < 0.5 in both periods)",
                                                   "Becomes suitable\n(S < 0.5 → S ≥ 0.5)",
                                                   "Remains suitable\n(S ≥ 0.5 in both periods)",
                                                   "Becomes unsuitable\n(S ≥ 0.5 → S < 0.5)"))

  # Create plots
  cat("  Creating panels...\n")

  # Panel 1: Discrete Difference Map
  p1 <- ggplot() +
    geom_raster(data = df_diff, aes(x = x, y = y, fill = change_cat)) +
    geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
    scale_fill_manual(
      values = c("Substantial decrease\n(< -0.15)" = "#053061",
                 "Moderate decrease\n(-0.15 to -0.10)" = "#2166AC",
                 "Slight decrease\n(-0.10 to -0.05)" = "#92C5DE",
                 "No change\n(-0.05 to 0.05)" = "white",
                 "Slight increase\n(0.05 to 0.10)" = "#F4A582",
                 "Moderate increase\n(0.10 to 0.15)" = "#D6604D",
                 "Substantial increase\n(> 0.15)" = "#B2182B"),
      breaks = c("Substantial decrease\n(< -0.15)",
                 "Moderate decrease\n(-0.15 to -0.10)",
                 "Slight decrease\n(-0.10 to -0.05)",
                 "Slight increase\n(0.05 to 0.10)",
                 "Moderate increase\n(0.10 to 0.15)",
                 "Substantial increase\n(> 0.15)"),
      na.value = "transparent",
      name = NULL,
      drop = FALSE,
      guide = guide_legend(
        title.position = "top",
        title.hjust = 0.5,
        direction = "horizontal",
        label.position = "bottom",
        nrow = 3,
        ncol = 2,
        byrow = FALSE
      )
    ) +
    coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
    labs(title = if(spp_idx == 1) "Change in suitability (2100, SSP2-4.5)" else NULL) +
    theme_minimal(base_size = 14) +
    theme(
      panel.background = element_rect(fill = "aliceblue"),
      panel.grid = element_line(color = "white", linewidth = 0.3),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
      legend.position = if(spp_idx == 1) "none" else "bottom",
      legend.box = "horizontal",
      legend.key.width = unit(1.5, "cm"),
      legend.key.height = unit(0.5, "cm"),
      legend.text = element_text(size = 13),
      legend.title = element_text(size = 15, face = "bold"),
      legend.key = element_rect(color = "grey50", linewidth = 0.5),
      axis.title = element_blank(),
      axis.text.y = element_text(size = 12),
      axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12)
    )

  # Panel 2: Suitability Transition Map
  p2 <- ggplot() +
    geom_raster(data = df_transition, aes(x = x, y = y, fill = transition_cat)) +
    geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
    scale_fill_manual(
      values = c("Remains unsuitable\n(S < 0.5 in both periods)" = "#CCCCCC",
                 "Becomes suitable\n(S < 0.5 → S ≥ 0.5)" = "#B2182B",
                 "Becomes unsuitable\n(S ≥ 0.5 → S < 0.5)" = "#2166AC",
                 "Remains suitable\n(S ≥ 0.5 in both periods)" = "orange"),
      na.value = "transparent",
      name = NULL,
      drop = FALSE,
      guide = guide_legend(
        title.position = "top",
        title.hjust = 0.5,
        direction = "horizontal",
        label.position = "bottom",
        nrow = 2,
        ncol = 2,
        byrow = TRUE
      )
    ) +
    coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
    labs(title = if(spp_idx == 1) sprintf("Suitability transitions (threshold S = %.1f)", suitability_threshold) else NULL) +
    theme_minimal(base_size = 14) +
    theme(
      panel.background = element_rect(fill = "aliceblue"),
      panel.grid = element_line(color = "white", linewidth = 0.3),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
      legend.position = if(spp_idx == 1) "none" else "bottom",
      legend.box = "horizontal",
      legend.key.width = unit(1.5, "cm"),
      legend.key.height = unit(0.5, "cm"),
      legend.text = element_text(size = 13),
      legend.title = element_text(size = 15, face = "bold"),
      legend.key = element_rect(color = "grey50", linewidth = 0.5),
      axis.title = element_blank(),
      axis.text.y = element_blank(),
      axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12)
    )

  # Store plots in list
  cat("  Storing panels...\n")
  all_plots[[length(all_plots) + 1]] <- p1
  all_plots[[length(all_plots) + 1]] <- p2

  # Clean up
  rm_vars <- c("rasters", "r_suit_current", "r_suit_ssp245", "r_diff",
               "r_transition", "df_diff", "df_transition", "p1", "p2")

  rm(list = rm_vars[rm_vars %in% ls()])
  gc(verbose = FALSE)

  cat(sprintf("✅ Species %d/%d processed\n", spp_idx, length(species_list)))
}

# Combine all plots in 2x2 grid (2 rows, 2 columns)
cat("\n=== Creating final combined figure ===\n")

# Get species names for row labels
species_name_1 <- species_list[[1]]$name
species_name_2 <- species_list[[2]]$name

if (length(all_plots) == 4) {
  # Two species, two panels each (2 rows x 2 columns)
  row1 <- wrap_plots(all_plots[[1]], all_plots[[2]], nrow = 1)
  row2 <- wrap_plots(all_plots[[3]], all_plots[[4]], nrow = 1)

  combined_plot <- row1 / row2

  plot_title <- "Species distribution models - Change and transitions"
  out_filename <- "2species_change_and_transitions_ssp245_new.png"
  plot_width <- 18
  plot_height <- 14
} else {
  stop("Unexpected number of plots. Expected 4 plots.")
}

combined_plot <- combined_plot +
  plot_annotation(
    tag_levels = "a",
    theme = theme(
      plot.tag = element_text(size = 34, face = "bold", family = "Helvetica")
    )
  ) &
  theme(plot.margin = margin(5, 5, 5, 30))  # Add left margin for species labels

# Save plot with species labels
out_file <- file.path(plot_dir, out_filename)

# Save the base plot first
ggsave(out_file, combined_plot,
       width = plot_width, height = plot_height, dpi = 300, bg = "white")

# Now add species labels using grid
library(grid)
library(gridExtra)

# Reopen the saved plot and add text annotations
png(out_file, width = plot_width, height = plot_height, units = "in", res = 300, bg = "white")

# Draw the combined plot
print(combined_plot)

# Add species names vertically on the left side
# Calculate vertical positions for each row (centered)
grid.text(species_name_1,
          x = unit(0.19, "npc"),
          y = unit(0.80, "npc"),
          rot = 90,
          gp = gpar(fontsize = 18, fontface = "bold.italic"))

grid.text(species_name_2,
          x = unit(0.19, "npc"),
          y = unit(0.38, "npc"),
          rot = 90,
          gp = gpar(fontsize = 18, fontface = "bold.italic"))

dev.off()

cat(sprintf("\n✅ Created combined figure: %s\n", out_file))
cat("✅ Plot saved in:", plot_dir, "\n")
