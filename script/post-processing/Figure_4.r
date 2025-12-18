library(terra)
library(ggplot2)
library(sf)
library(rnaturalearth)
library(dplyr)

base_dir <- "C:/biomod2_git/post_modelisation/species_maps_mix50_DISTFIX"
scenario_name <- "current"

# European extent
xlim_eu <- c(-28, 70)
ylim_eu <- c(28, 83)

# Load world map
world <- ne_countries(scale = "medium", returnclass = "sf")

# Load stacked normalized suitability
stack_suit_path <- file.path(base_dir, paste0(scenario_name, "_proj/masked/alien/stacked_norm01"),
                             paste0("new_stack_mean_norm01_", scenario_name, ".tif"))

r_stack_suit <- rast(stack_suit_path)

# Create discrete categories (0-0.1, 0.1-0.2, etc.)
breaks <- seq(0, 1, by = 0.1)

# Convert to dataframe
df_discrete <- as.data.frame(r_stack_suit, xy = TRUE)
names(df_discrete)[3] <- "value"
df_discrete <- df_discrete[!is.na(df_discrete$value), ]

# Create category labels using cut
df_discrete$cat_label <- cut(df_discrete$value,
                              breaks = breaks,
                              labels = c("0.0-0.1","0.1-0.2", "0.2-0.3", "0.3-0.4",
                                        "0.4-0.5", "0.5-0.6", "0.6-0.7", "0.7-0.8",
                                        "0.8-0.9", "0.9-1.0"),
                              include.lowest = TRUE)

# Define custom colors for each category
custom_colors <- c("0.0-0.1" = "lightcyan",
                   "0.1-0.2" = "lightblue1",
                   "0.2-0.3" = "lightblue2",
                   "0.3-0.4" = "lightblue3",
                   "0.4-0.5" = "tomato1",
                   "0.5-0.6" = "firebrick2",
                   "0.6-0.7" = "firebrick4",
                   "0.7-0.8" = "orangered4",
                   "0.8-0.9" = "coral4",
                   "0.9-1.0" = "darkred")


# Check unique levels in data (for debugging)
cat("Unique categories in data:\n")
print(unique(df_discrete$cat_label))

# Create publication-ready plot for NIS management priorities
library(ggspatial)  # For scale bar and north arrow

p <- ggplot() +
  geom_raster(data = df_discrete, aes(x = x, y = y, fill = cat_label)) +
  geom_sf(data = world, fill = "grey95", color = "grey40", linewidth = 0.1) +
  scale_fill_manual(
    values = custom_colors,
    name = expression(paste(bold("Management Priority "), italic("(S: mean suitability)"))),
    labels = c("0.0-0.1" = expression(paste("Negligible  ", italic("(S<0.1)"))),
               "0.1-0.2" = expression(paste("Low ", italic("(0.1<S<0.2)"))),
               "0.2-0.3" = expression(paste("Low-Moderate ", italic("(0.2<S<0.3)"))),
               "0.3-0.4" = expression(paste("Moderate ", italic("(0.3<S<0.4)"))),
               "0.4-0.5" = expression(paste("Moderate-High ", italic("(0.4<S<0.5)"))),
               "0.5-0.6" = expression(paste("High ", italic("(0.5<S<0.6)"))),
               "0.6-0.7" = expression(paste("Severe ", italic("(0.6<S<0.7)"))),
               "0.7-0.8" = expression(paste("Severe ", italic("(0.7<S<0.8)"))),
               "0.8-0.9" = expression(paste("Critical ", italic("(0.8<S<0.9)"))),
               "0.9-1.0" = expression(paste("Critical ", italic("(0.9<S<1.0)")))),
    na.value = "transparent",
    drop = TRUE
  ) +
  coord_sf(xlim = xlim_eu, ylim = ylim_eu, expand = FALSE) +
  #labs(
  #  title = "Priority Areas for Non-native Invasive Species Management",
  #  subtitle = "Based on stacked ensemble habitat suitability predictions (70 NIS; current climate)"
  #) +
  theme_minimal(base_size = 13, base_family = "sans") +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    panel.grid.major = element_line(color = "grey85", linewidth = 0.25),
    panel.grid.minor = element_blank(),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
    plot.title = element_text(face = "bold", size = 16, hjust = 0, margin = margin(b = 5)),
    plot.subtitle = element_text(size = 11, hjust = 0, color = "grey30", margin = margin(b = 15)),
    plot.margin = margin(15, 15, 15, 15),
    legend.position = "right",
    legend.key.height = unit(1, "cm"),
    legend.key.width = unit(0.6, "cm"),
    legend.text = element_text(size = 11),
    legend.title = element_text(size = 14, face = "bold", margin = margin(b = 8)),
    legend.background = element_rect(fill = "white", color = "grey70", linewidth = 0.3),
    legend.margin = margin(10, 10, 10, 10),
    legend.key = element_rect(color = "grey60", linewidth = 0.2),
    axis.title = element_blank(),
    axis.text = element_text(size = 12, color = "grey30")
  )

# Save plot
out_dir <- file.path(base_dir, "discrete_maps")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Save high-resolution publication version
ggsave(file.path(out_dir, "suitability_discrete_current_publication_new_mod.png"),
       p, width = 12, height = 10, dpi = 600, bg = "white")

cat("✅ Discrete map created!\n")