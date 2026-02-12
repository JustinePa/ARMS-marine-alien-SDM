library(terra)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(dplyr)
library(patchwork)
library(grid)
library(gridExtra)

base_dir      <- "path/to/your/working/directory"  # EDIT: set once here
emcv_base_dir <- file.path(base_dir, "EMcv")
emca_base_dir <- file.path(base_dir, "EMca/EMca_normalized")
plot_dir <- file.path(base_dir, "figures/species_plots_3panel")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

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
# Note: This script produces a 2-species example figure (Figure 2).
# To reproduce the published figure, keep the species_list as provided.
# To generate equivalent plots for other species, update species_list.

# Pick scenario
scenario_name <- "current"

# Initialize list to store all plots
all_plots <- list()

# Loop through each species
for (spp_idx in seq_along(species_list)) {
  species_code <- species_list[[spp_idx]]$code
  species_name <- species_list[[spp_idx]]$name

  cat(sprintf("\n=== Processing species %d/%d: %s ===\n", spp_idx, length(species_list), species_name))
  cat(sprintf("Loading data for: %s\n", scenario_name))

  # Paths
  masked_emcv_dir <- file.path(emcv_base_dir, scenario_name, "masked_emcv_alien")
  masked_suit_dir <- file.path(base_dir, paste0(scenario_name, "_proj/masked/alien/normalized"))
  emca_scenario_dir <- file.path(emca_base_dir, scenario_name)

  # Find files
  emcv_file <- list.files(masked_emcv_dir,
                          pattern = paste0("ALIENMASK_", species_code, "_EMcvByTSS.*\\.tif$"),
                          full.names = TRUE)

  suit_file <- list.files(masked_suit_dir,
                          pattern = paste0("ALIENMASK_MASKED_", species_code, ".*norm01\\.tif$"),
                          full.names = TRUE)

  emca_file <- list.files(emca_scenario_dir,
                          pattern = paste0(species_code, "_EMcaByTSS.*\\.tif$"),
                          full.names = TRUE)

  if (length(emcv_file) == 0 || length(suit_file) == 0) {
    stop(paste("  ⚠️ Suitability or EMcv files not found for", scenario_name))
  }

  if (length(emca_file) == 0) {
    warning(paste("  ⚠️ EMca file not found for", scenario_name, "- will skip Panel 3"))
    emca_available <- FALSE
  } else {
    emca_available <- TRUE
  }

  # Read rasters
  r_suit_current <- rast(suit_file[1])
  r_emcv <- rast(emcv_file[1])
  r_cv_current <- r_emcv / 100 # convert EMcv from 0-100 to 0-1 scale

  if (emca_available) {
    r_emca_current <- rast(emca_file[1])

    # Check EMca value range
    emca_range <- global(r_emca_current, range, na.rm = TRUE)
    cat(sprintf("  EMca range: [%.3f, %.3f]\n", emca_range[1, 1], emca_range[2, 1]))
  }

  cat(sprintf("  Loaded suitability and CV rasters\n"))

  # Panel 1: Full continuous suitability (current)
  r_suit_full <- r_suit_current

  # Panel 2: CV masked to suitable areas (S > 0.3)
  suitability_threshold <- 0.3

  # Create mask for suitable areas (S > 0.3)
  suitable_mask <- ifel(r_suit_current > suitability_threshold, 1, NA)

  # Mask CV to only suitable areas
  r_cv_masked <- mask(r_cv_current, suitable_mask)

  # Create mask for low suitability areas (S <= 0.3)
  low_suit_mask <- ifel(r_suit_current <= suitability_threshold, 1, NA)

  # Panel 3: EMca (if available)
  if (emca_available) {
    r_emca_display <- r_emca_current
  }

  # Convert to dataframes
  cat("  Converting rasters to dataframes...\n")

  # Panel 1: Full suitability
  df_suit_full <- as.data.frame(r_suit_full, xy = TRUE)
  names(df_suit_full)[3] <- "suitability"
  df_suit_full <- df_suit_full[!is.na(df_suit_full$suitability), ]

  # Panel 2: CV masked to suitable areas
  df_cv_masked <- as.data.frame(r_cv_masked, xy = TRUE)
  names(df_cv_masked)[3] <- "cv"
  df_cv_masked <- df_cv_masked[!is.na(df_cv_masked$cv), ]

  df_low_suit <- as.data.frame(low_suit_mask, xy = TRUE)
  names(df_low_suit)[3] <- "low_suit"
  df_low_suit <- df_low_suit[!is.na(df_low_suit$low_suit), ]

  # Panel 3: EMca
  if (emca_available) {
    df_emca <- as.data.frame(r_emca_display, xy = TRUE)
    names(df_emca)[3] <- "emca"
    df_emca <- df_emca[!is.na(df_emca$emca), ]
  }

  # Create plots
  cat("  Creating panels...\n")

  # Panel 1: Continuous Habitat Suitability (0-1 scale)
  p1 <- ggplot() +
    geom_raster(data = df_suit_full, aes(x = x, y = y, fill = suitability)) +
    geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
    scale_fill_gradientn(
      colors = rev(c("#440154", "#31688E", "#35B779", "#FDE724")),  # viridis reversed
      na.value = "transparent",
      name = "Suitability",
      limits = c(0, 1),
      guide = guide_colorbar(title.position = "top", title.hjust = 0.5)
    ) +
    coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
    labs(title = if(spp_idx == 1) "Habitat suitability" else NULL) +
    theme_minimal(base_size = 14) +
    theme(
      panel.background = element_rect(fill = "aliceblue"),
      panel.grid = element_line(color = "white", linewidth = 0.3),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
      legend.position = if(spp_idx == 1) "none" else "bottom",
      legend.box = "horizontal",
      legend.key.width = unit(2, "cm"),
      legend.key.height = unit(0.5, "cm"),
      legend.text = element_text(size = 13),
      legend.title = element_text(size = 15, face = "bold"),
      axis.title = element_blank(),
      axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12),
      axis.text.y = element_text(size = 12)
    )

  # Panel 2: CV masked to suitable areas (S > 0.3)
  p2 <- ggplot() +
    # First plot low suitability areas in white
    geom_raster(data = df_low_suit, aes(x = x, y = y, alpha = "Low suitability\n(CV not shown)"), fill = "white") +
    # Then plot CV values in suitable areas
    geom_raster(data = df_cv_masked, aes(x = x, y = y, fill = cv)) +
    geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
    scale_fill_gradientn(
      colors = c("#FFFFE0", "#FED976", "#FEB24C", "#FD8D3C", "#FC4E2A", "#E31A1C", "#B10026"),  # Yellow to red
      na.value = "transparent",
      name = "Coefficient of Variation (CV)",
      limits = c(0, 1),
      guide = guide_colorbar(title.position = "top", title.hjust = 0.5)
    ) +
    scale_alpha_manual(
      name = "",
      values = c("Low suitability\n(CV not shown)" = 1),
      guide = guide_legend(
        override.aes = list(fill = "white"),
        title = NULL,
        label.position = "right",
        keywidth = unit(0.8, "cm"),
        keyheight = unit(0.8, "cm")
      )
    ) +
    coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
    labs(title = if(spp_idx == 1) sprintf("Uncertainty in suitable areas (S > %.1f)", suitability_threshold) else NULL) +
    theme_minimal(base_size = 14) +
    theme(
      panel.background = element_rect(fill = "aliceblue"),
      panel.grid = element_line(color = "white", linewidth = 0.3),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
      plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.key.width = unit(2, "cm"),
      legend.key.height = unit(0.5, "cm"),
      legend.text = element_text(size = 13),
      legend.title = element_text(size = 15, face = "bold"),
      axis.title = element_blank(),
      axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12),
      axis.text.y = element_blank()
    ) +
    guides(
      fill = guide_colorbar(title.position = "top", title.hjust = 0.5, order = 1),
      alpha = guide_legend(
        title = NULL,
        override.aes = list(fill = "white"),
        label.position = "right",
        keywidth = unit(0.8, "cm"),
        keyheight = unit(0.8, "cm"),
        order = 2
      )
    )

  # Add mask legend inside panel using annotation
  if (spp_idx == 1) {
    # First species: hide legend, add annotation box
    p2 <- p2 +
      theme(
        legend.position = "none",
        axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12),
        axis.text.y = element_blank()
      ) +
      annotation_custom(
        grob = grid::rectGrob(
          gp = grid::gpar(fill = "white", col = "grey50", lwd = 0.5, alpha = 0.9)
        ),
        xmin = 38, xmax = 69, ymin = 29, ymax = 34
      ) +
      annotation_custom(
        grob = grid::rectGrob(
          width = unit(0.7, "cm"),
          height = unit(0.7, "cm"),
          gp = grid::gpar(fill = "white", col = "grey50", lwd = 1)
        ),
        xmin = 40, xmax = 48, ymin = 30.5, ymax = 32.5
      ) +
      annotation_custom(
        grob = grid::textGrob(
          label = "Low suitability\n(CV not shown)",
          x = 0,
          y = 0.5,
          hjust = 0,
          gp = grid::gpar(fontsize = 11, col = "black", fontface = "plain")
        ),
        xmin = 49, xmax = 68, ymin = 30, ymax = 33
      )
  } else {
    # Second species: show legend, add annotation box
    p2 <- p2 +
      theme(
        legend.position = "bottom",
        legend.box = "horizontal",
        legend.key.width = unit(2, "cm"),
        legend.key.height = unit(0.5, "cm"),
        legend.text = element_text(size = 13),
        legend.title = element_text(size = 15, face = "bold"),
        axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12),
        axis.text.y = element_blank()
      ) +
      guides(
        fill = guide_colorbar(title.position = "top", title.hjust = 0.5),
        alpha = "none"
      ) +
      annotation_custom(
        grob = grid::rectGrob(
          gp = grid::gpar(fill = "white", col = "grey50", lwd = 0.5, alpha = 0.9)
        ),
        xmin = 39, xmax = 69, ymin = 29, ymax = 34
      ) +
      annotation_custom(
        grob = grid::rectGrob(
          width = unit(0.7, "cm"),
          height = unit(0.7, "cm"),
          gp = grid::gpar(fill = "white", col = "grey50", lwd = 1)
        ),
        xmin = 40, xmax = 48, ymin = 30.5, ymax = 32.5
      ) +
      annotation_custom(
        grob = grid::textGrob(
          label = "Low suitability\n(CV not shown)",
          x = 0,
          y = 0.5,
          hjust = 0,
          gp = grid::gpar(fontsize = 11, col = "black", fontface = "plain")
        ),
        xmin = 48, xmax = 68, ymin = 30, ymax = 33
      )
  }

  # Panel 3: EMca (Committee Averaging)
  # 0 = models agree on absence, 1 = models agree on presence, 0.5 = disagreement
  if (emca_available) {
    p3 <- ggplot() +
      geom_raster(data = df_emca, aes(x = x, y = y, fill = emca)) +
      geom_sf(data = world, fill = "grey90", color = "grey60", linewidth = 0.2) +
      scale_fill_gradient2(
        low = "#2166AC",      # Blue for 0 (agreement on absence)
        mid = "#FFFFBF",      # Yellow for 0.5 (disagreement)
        high = "#B2182B",     # Red for 1 (agreement on presence)
        midpoint = 0.5,
        na.value = "transparent",
        name = "Committee Averaging",
        limits = c(0, 1),
        guide = guide_colorbar(title.position = "top", title.hjust = 0.5)
      ) +
      coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
      labs(title = if(spp_idx == 1) "Model agreement" else NULL) +
      theme_minimal(base_size = 14) +
      theme(
        panel.background = element_rect(fill = "aliceblue"),
        panel.grid = element_line(color = "white", linewidth = 0.3),
        panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
        plot.title = element_text(face = "bold", size = 16, hjust = 0.5),
        legend.position = if(spp_idx == 1) "none" else "bottom",
        legend.box = "horizontal",
        legend.key.width = unit(2, "cm"),
        legend.key.height = unit(0.5, "cm"),
        legend.text = element_text(size = 13),
        legend.title = element_text(size = 15, face = "bold"),
        axis.title = element_blank(),
        axis.text.x = if(spp_idx == 1) element_blank() else element_text(size = 12),
        axis.text.y = element_blank()
      )
  }

  # Store plots in list
  cat("  Storing panels...\n")

  if (emca_available) {
    all_plots[[length(all_plots) + 1]] <- p1
    all_plots[[length(all_plots) + 1]] <- p2
    all_plots[[length(all_plots) + 1]] <- p3
  } else {
    all_plots[[length(all_plots) + 1]] <- p1
    all_plots[[length(all_plots) + 1]] <- p2
  }

  # Clean up
  rm_vars <- c("r_suit_current", "r_cv_current", "r_suit_full", "r_cv_masked",
               "suitable_mask", "low_suit_mask", "df_suit_full", "df_cv_masked",
               "df_low_suit", "p1", "p2")

  if (emca_available) {
    rm_vars <- c(rm_vars, "r_emca_current", "r_emca_display", "df_emca", "p3")
  }

  rm(list = rm_vars[rm_vars %in% ls()])
  gc(verbose = FALSE)

  cat(sprintf("✅ Species %d/%d processed\n", spp_idx, length(species_list)))
}

# Combine all plots in 2x3 grid
cat("\n=== Creating final combined figure ===\n")

# Get species names for row labels
species_name_1 <- species_list[[1]]$name
species_name_2 <- species_list[[2]]$name

if (length(all_plots) == 6) {
  # Two species, three panels each (2 rows x 3 columns)
  # Create wrap plots to add species labels
  row1 <- wrap_plots(all_plots[[1]], all_plots[[2]], all_plots[[3]], nrow = 1)
  row2 <- wrap_plots(all_plots[[4]], all_plots[[5]], all_plots[[6]], nrow = 1)

  combined_plot <- row1 / row2

  plot_title <- "Species distribution models - Suitability and uncertainty"
  out_filename <- "2species_3panel_CV_EMca_masked_new.png"
  plot_width <- 20
  plot_height <- 14
} else if (length(all_plots) == 4) {
  # Two species, two panels each (2 rows x 2 columns)
  row1 <- wrap_plots(all_plots[[1]], all_plots[[2]], nrow = 1)
  row2 <- wrap_plots(all_plots[[3]], all_plots[[4]], nrow = 1)

  combined_plot <- row1 / row2

  plot_title <- "Species distribution models - Suitability and uncertainty"
  out_filename <- "Figure_2.png"
  plot_width <- 16
  plot_height <- 14
} else {
  stop("Unexpected number of plots. Expected 4 or 6 plots.")
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


# Reopen the saved plot and add text annotations
png(out_file, width = plot_width, height = plot_height, units = "in", res = 300, bg = "white")

# Draw the combined plot
print(combined_plot)

# Add species names vertically on the left side
# Calculate vertical positions for each row (centered)
grid.text(species_name_1,
          x = unit(0.02, "npc"),
          y = unit(0.75, "npc"),
          rot = 90,
          gp = gpar(fontsize = 18, fontface = "bold.italic"))

grid.text(species_name_2,
          x = unit(0.02, "npc"),
          y = unit(0.29, "npc"),
          rot = 90,
          gp = gpar(fontsize = 18, fontface = "bold.italic"))

dev.off()

cat(sprintf("\n✅ Created combined figure: %s\n", out_file))
cat("✅ Plot saved in:", plot_dir, "\n")


