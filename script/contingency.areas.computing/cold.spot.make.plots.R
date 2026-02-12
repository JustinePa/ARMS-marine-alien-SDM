################################################################################
# Cold Spot Analysis - Publication Figure Generation Script
################################################################################
# 
# Purpose: Generate publication-ready two-panel figure showing cold spot 
#          identification results for marine non-indigenous species management.
#
# Figure design:
#   Panel A (left): Ensemble suitability map with infrastructure overlays
#     - Continuous suitability gradient (0-1 scale, 10 bins)
#     - Marine Protected Areas (MPAs)
#     - Offshore Wind Farms (OWFs)
#     - Identified cold spots
#     - Comprehensive legend with all categories
#
#   Panel B (right): Cold spot focus map
#     - Model extent (areas with suitability predictions)
#     - Cold spot polygons highlighted
#     - Simplified visualization for clarity
#
# Technical approach:
#   - Raster layers converted to data frames for ggplot2 compatibility
#   - "Dummy points" added outside plot extent to force legend categories
#   - Color scheme optimized for colorblind accessibility
#   - Coordinated reference system preserved throughout
#
# Outputs:
#   - Two-panel PDF figure (vector format for journal submission)
#   - Alternative PNG output available (adjust width/height units)
#
# Inputs (via command line arguments):
#   - Processed spatial layers from previous scripts
#   - Cold spot polygons and MPA polygons
#   - Plot extent and formatting parameters
#
# Note: Individual panels stored as R objects (left.panel, right.panel) 
#       for debugging. To inspect: copy args from environment (args <- Args3)
#       and run interactively in RStudio.
#
# Author: Mats Gunnar Andersson
# Institution: SVA - Swedish Veterinary Institute
# Contact: gunnar.andersson@sva.se
# Date Created: November 2025
# Last Modified: 2026-01-13
################################################################################

library(ggplot2)
library(fBasics)
library(ggpubr)
library(terra)
library(raster)
library(sf)
library(maptools)
library(dplyr)
library(stars)

################################################################################
# Parse Command Line Arguments
################################################################################

args <- commandArgs(trailingOnly = TRUE)

# For RStudio debugging: args <- Args3

cat("Received", length(args), "arguments\n")
cat(paste("Argument", seq_along(args), "=", args, collapse = "\n"), "\n\n")

# Input layers
suitability.rasterlayer.crop.layer <- args[1]
mpa.rasterlayer_dist.layer <- args[2]
owf.rasterlayer_dist.layer <- args[3]
coast.rasterlayer_dist.layer <- args[4]

# Polygon layers for plotting
world1geometry.crop.layer <- args[5]
shape.owf.crop.layer <- args[6]
mpa.rasterlayer.crop.layer <- args[7]

# Cold spot parameters (for reference)
MPA.range.max <- as.numeric(args[8])
MPA.limit <- as.numeric(args[9])
OWF.range.max <- as.numeric(args[10])
OWF.limit <- as.numeric(args[11])
coast.range.max <- as.numeric(args[12])
coast.limit <- as.numeric(args[13])
suitability.range.max <- as.numeric(args[14])
suitability.limit <- as.numeric(args[15])
plot.data <- as.logical(args[16])

# Cold spot output files
Coldspot.layer <- args[17]
MPA.polygon.layer <- args[18]

# Plot extent
xlim3 <- as.numeric(c(args[19], args[20]))
ylim3 <- as.numeric(c(args[21], args[22]))

# Output specifications
plotname <- args[23]
plotwidth <- as.numeric(args[24])    # cm for PDF
plotheight <- as.numeric(args[25])   # cm for PDF
plotres <- as.numeric(args[26])      # dpi (for PNG option)

################################################################################
# Load Spatial Layers
################################################################################

cat("LOADING SPATIAL LAYERS\n")

cat("Loading ensemble suitability...\n")
suitability.rasterlayer <- raster(suitability.rasterlayer.crop.layer)

cat("Loading country boundaries...\n")
load(world1geometry.crop.layer)

cat("Loading offshore wind farms...\n")
load(shape.owf.crop.layer)

cat("Loading cold spot polygons...\n")
load(Coldspot.layer)  # unifiedPolygons

cat("Loading MPA polygons...\n")
load(MPA.polygon.layer)  # unifiedMPAPolygons

################################################################################
# Transform Polygons to SF Objects
################################################################################

cat("Converting polygon layers to SF format...\n")
unifiedPolygons.sf <- sf::st_as_sf(unifiedPolygons)
world1geometry.sf <- sf::st_as_sf(world1geometry)
shape.owf.sf <- sf::st_as_sf(shape.owf)
unifiedMPAPolygons.sf <- sf::st_as_sf(unifiedMPAPolygons)
cat("Polygon conversion complete\n\n")

################################################################################
# Prepare Suitability Data for Plotting
################################################################################

cat("PREPARING SUITABILITY DATA\n")

# Define breaks for discrete categories
# 10 bins from 0 to suitability.range.max, plus 4 categories for polygons
breaks <- c(
  seq(0, suitability.range.max, by = suitability.range.max / 10),
  suitability.range.max + 0.5,   # OWF placeholder
  suitability.range.max + 1.5,   # MPA placeholder
  suitability.range.max + 2.5,   # Cold spot placeholder
  suitability.range.max + 3.5    # NA placeholder
)

cat("Created", length(breaks) - 1, "category breaks\n")
cat("  Suitability bins: 10 (0 to", suitability.range.max, ")\n")
cat("  Additional categories: OWF, MPA, Cold spot, NA\n\n")

# Convert raster to data frame
cat("Converting suitability raster to data frame...\n")
df_discrete <- as.data.frame(suitability.rasterlayer, xy = TRUE)
names(df_discrete)[3] <- "value"
df_discrete <- df_discrete[!is.na(df_discrete$value), ]

# Create truncated values (capped at suitability.range.max)
df_discrete$trunk_value <- ifelse(
  df_discrete$value > suitability.range.max,
  suitability.range.max,
  df_discrete$value
)

# Add dummy points outside plot extent to force legend categories
# These points are westernmost (max x) and won't appear in final plot
cat("Adding dummy points for legend categories...\n")
max_x_indices <- which(df_discrete$x == max(df_discrete$x))

df_discrete$trunk_value[max_x_indices[1]] <- suitability.range.max + 0.1  # OWF
df_discrete$trunk_value[max_x_indices[2]] <- suitability.range.max + 1.0  # MPA
df_discrete$trunk_value[max_x_indices[3]] <- suitability.range.max + 2.0  # Cold spot
df_discrete$trunk_value[max_x_indices[4]] <- suitability.range.max + 3.0  # NA

# Categorize values
cat("Assigning category labels...\n")
df_discrete$cat_label <- cut(
  df_discrete$trunk_value,
  breaks = breaks,
  labels = c(seq(1, 10), "OWF", "MPA", "Cold spot", "NA"),
  include.lowest = TRUE
)

cat("Data preparation complete\n\n")

################################################################################
# Define Color Scheme
################################################################################

cat("DEFINING COLOR SCHEME\n")

# Colorblind-friendly palette
# Blues gradient for suitability + distinct colors for infrastructure/management

blue.colors <- c(
  seqPalette(10, "Blues"),
  "#E1BE6A",  # OWF
  "#40B0A6",  # MPA
  "#994F00",  # Cold spot
  "darkgrey"  # NA
)

custom_colors <- c(
  "1" = blue.colors[1], "2" = blue.colors[2], "3" = blue.colors[3],
  "4" = blue.colors[4], "5" = blue.colors[5], "6" = blue.colors[6],
  "7" = blue.colors[7], "8" = blue.colors[8], "9" = blue.colors[9],
  "10" = blue.colors[10],
  "OWF" = blue.colors[11], "MPA" = blue.colors[12],
  "Cold spot" = blue.colors[13], "NA" = blue.colors[14]
)

################################################################################
# Create Panel A: Suitability with Infrastructure Overlay
################################################################################

cat("CREATING PANEL A: SUITABILITY MAP\n")

left.panel <- ggplot() +
  # Base layer: suitability raster
  geom_raster(data = df_discrete, aes(x = x, y = y, fill = cat_label)) +
  
  # Country boundaries
  geom_sf(data = world1geometry.sf, fill = "grey95", color = "grey40", 
          linewidth = 0.1) +
  
  # Color scale with custom labels
  scale_fill_manual(
    values = custom_colors,
    name = expression(paste("", italic("Mean suitability"))),
    labels = c(
      "1" = paste("<", breaks[2]),
      "2" = paste("<", breaks[3]),
      "3" = paste("<", breaks[4]),
      "4" = paste("<", breaks[5]),
      "5" = paste("<", breaks[6]),
      "6" = paste("<", breaks[7]),
      "7" = paste("<", breaks[8]),
      "8" = paste("<", breaks[9]),
      "9" = paste("<", breaks[10]),
      "10" = paste(">", breaks[10]),
      "OWF" = "OWF",
      "MPA" = "MPA",
      "Cold spot" = "Cold spot",
      "NA" = "NA"
    ),
    na.value = "transparent",
    guide = guide_legend(
      title.position = "top",
      title.hjust = 0.5,
      direction = "horizontal",
      label.position = "left",
      nrow = 14,  # Fixed: was 13, needed 14 for all categories
      ncol = 1,
      byrow = FALSE
    ),
    drop = TRUE
  ) +
  
  # Set map extent
  coord_sf(xlim = xlim3, ylim = ylim3, expand = FALSE) +
  
  # Theme elements
  theme(
    panel.background = element_rect(fill = "darkgrey"),
    panel.grid = element_line(color = "white", linewidth = 0.3),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
    plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
    legend.position = "left",
    legend.box = "horizontal",
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(0.5, "cm"),
    legend.text = element_text(size = 20),
    legend.title = element_text(size = 24, face = "bold"),
    legend.key = element_rect(color = "grey50", linewidth = 0.5),
    axis.title = element_blank()
  ) +
  
  # Overlay offshore wind farms
  geom_sf(data = shape.owf.sf, colour = "#E1BE6A", fill = "#E1BE6A") +
  coord_sf(xlim = xlim3, ylim = ylim3, expand = FALSE) +
  
  # Overlay marine protected areas
  geom_sf(data = unifiedMPAPolygons.sf, colour = "#40B0A6", fill = "#40B0A6") +
  coord_sf(xlim = xlim3, ylim = ylim3, expand = FALSE)

cat("Panel A complete\n\n")

################################################################################
# Create Panel B: Cold Spot Focus Map
################################################################################

cat("CREATING PANEL B: COLD SPOT MAP\n")

# Create mock data frame showing model extent
df_discrete.mock <- df_discrete
df_discrete.mock$not.na <- cut(
  df_discrete$trunk_value,
  breaks = c(0, 0.5, 1),
  labels = c("in_model", "in_model_too"),
  include.lowest = TRUE
)

custom_colors2 <- c("in_model" = "aliceblue", "in_model_too" = "aliceblue")

right.panel <- ggplot() +
  # Base layer: model extent
  geom_raster(data = df_discrete.mock, aes(x = x, y = y, fill = not.na)) +
  
  # Country boundaries
  geom_sf(data = world1geometry.sf, fill = "grey90", colour = "grey60", 
          linewidth = 0.2) +
  
  # Simple color scale
  scale_fill_manual(
    values = custom_colors2,
    name = expression(paste("", italic("Model extent"))),
    labels = c("in_model" = "In model"),
    na.value = "transparent"
  ) +
  
  # Set map extent
  coord_sf(xlim = xlim3, ylim = ylim3, expand = FALSE) +
  
  # Theme elements
  theme(
    panel.background = element_rect(fill = "darkgrey"),
    panel.grid = element_line(color = "white", linewidth = 0.3),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 0.5),
    plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
    legend.box = "horizontal",
    legend.key.width = unit(1.5, "cm"),
    legend.key.height = unit(0.5, "cm"),
    legend.text = element_text(size = 10),
    legend.title = element_text(size = 12, face = "bold"),
    legend.key = element_rect(color = "grey50", linewidth = 0.5),
    axis.title = element_blank(),
    legend.position = "none"
  ) +
  
  # Overlay cold spot polygons
  geom_sf(data = unifiedPolygons.sf, colour = "#994F00", fill = "#994F00") +
  coord_sf(xlim = xlim3, ylim = ylim3, expand = FALSE)

cat("Panel B complete\n\n")

################################################################################
# Generate Two-Panel Figure
################################################################################

cat("GENERATING FIGURE\n")

# Alternative PNG output (uncomment and adjust units to mm):
# png(plotname, width = plotwidth, height = plotheight, units = "mm", res = plotres)

# Open PDF device
pdf(plotname, width = plotwidth, height = plotheight)

# Add panel labels
left.panel <- left.panel + 
  labs(title = "", subtitle = "a") + 
  theme(plot.subtitle = element_text(size = 24))

right.panel <- right.panel + 
  labs(title = "", subtitle = "b") + 
  theme(plot.subtitle = element_text(size = 24))

# Arrange panels with adjusted widths for legend
ggarrange(
  left.panel, right.panel,
  ncol = 2, nrow = 1,
  widths = c(1.25, 1)  # Left panel wider to accommodate legend
)

# Close device
dev.off()

cat("Figure saved successfully\n\n")

################################################################################
# Figure Generation Complete
################################################################################

cat("Output file:", normalizePath(plotname), "\n\n")

cat("Cold spot criteria applied:\n")
cat("  - Suitability <", suitability.limit, "\n")
cat("  - Distance from coast >", coast.limit, "km\n")
cat("  - Distance from MPAs >", MPA.limit, "km\n")
cat("  - Distance from OWFs >", OWF.limit, "km\n\n")
