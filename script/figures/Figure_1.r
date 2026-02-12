# ========== Figure 1: Model Performance Analysis ==========
# Creates Figure_1.pdf with two panels:
# Panel a: Scatter plot of TSS/AUC vs number of occurrences
# Panel b: Standard deviation decrease with sample size

# ========== Load Libraries ==========
library(ggplot2)
library(dplyr)
library(tidyr)
library(patchwork)

# individual_models_all_diagnostics.csv is produced by aggregating the
# per-species evaluation CSVs from the modelling pipeline:
# eval/{SpeciesName}_mixed_myExpl_shelf_kfold/eval_{SpeciesName}_{ModelingID}.csv
# In this step, ROC (from biomod2) is renamed AUC
# The file can be found in the figures/ repo

base_dir   <- "path/to/your/working/directory"
input_file <- file.path(base_dir, "plots_occ_vs_perf/individual_models_all_diagnostics.csv")
output_dir <- file.path(base_dir, "plots_occ_vs_perf")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ========== Load Pre-processed Data ==========
# Load the individual models diagnostics
if (!file.exists(input_file)) stop("Input file not found: ", input_file, " See in the Github repo")
results_all <- read.csv(input_file)

# Remove rows with missing data
results_plot <- results_all %>%
  filter(!is.na(n_occ) & !is.na(TSS) & !is.na(AUC))

# Add sample size categories
results_plot <- results_plot %>%
  mutate(
    sample_category = cut(n_occ,
                          breaks = c(0, 50, 100, 200, 500, Inf),
                          labels = c("<50", "50-100", "100-200", "200-500", ">500"))
  )

# ========== Panel a: Scatter Plot (TSS and AUC vs Occurrences) ==========
p1 <- ggplot(results_plot, aes(x = n_occ)) +
  geom_point(aes(y = TSS, color = "TSS"), size = 1.5, alpha = 0.3) +
  geom_point(aes(y = AUC, color = "AUC"), size = 1.5, alpha = 0.3) +
  geom_smooth(aes(y = TSS, color = "TSS"), method = "loess", se = TRUE, linewidth = 1.2) +
  geom_smooth(aes(y = AUC, color = "AUC"), method = "loess", se = TRUE, linewidth = 1.2) +
  scale_color_manual(values = c("TSS" = "#E69F00", "AUC" = "#56B4E9")) +
  labs(
    x = "Number of occurrences",
    y = "Model performance",
    color = "Metric"
  ) +
  theme_minimal(base_size = 9, base_family = "Helvetica") +
  theme(
    legend.position = "bottom",
    legend.text = element_text(size = 8),
    legend.title = element_text(size = 8),
    axis.text = element_text(size = 8, color = "black"),
    axis.title = element_text(size = 9, color = "black"),
    axis.title.x = element_text(margin = margin(t = 3)),
    axis.title.y = element_text(margin = margin(r = 3)),
    plot.title = element_blank(),
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5)
  )

# ========== Panel b: Standard Deviation Plot ==========

# Calculate SD by category
summary_stats <- results_plot %>%
  group_by(sample_category) %>%
  summarise(
    sd_TSS = sd(TSS, na.rm = TRUE),
    sd_AUC = sd(AUC, na.rm = TRUE),
    .groups = "drop"
  )

# Reshape for plotting
sd_data <- summary_stats %>%
  pivot_longer(
    cols = c(sd_TSS, sd_AUC),
    names_to = "metric",
    values_to = "sd_value",
    names_prefix = "sd_"
  ) %>%
  mutate(metric = toupper(metric))

# Create plot
p2 <- ggplot(sd_data, aes(x = sample_category, y = sd_value, color = metric, group = metric)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 3) +
  scale_color_manual(values = c("TSS" = "#E69F00", "AUC" = "#56B4E9")) +
  labs(
    x = "Number of occurrences",
    y = "Performance standard deviation",
    color = "Metric"
  ) +
  theme_minimal(base_size = 9, base_family = "Helvetica") +
  theme(
    plot.title = element_blank(),
    legend.position = "bottom",
    legend.text = element_text(size = 8),
    legend.title = element_text(size = 8),
    axis.text = element_text(size = 8, color = "black"),
    axis.title = element_text(size = 9, color = "black"),
    axis.title.x = element_text(margin = margin(t = 3)),
    axis.title.y = element_text(margin = margin(r = 3)),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    axis.line = element_line(color = "black", linewidth = 0.5),
    axis.ticks = element_line(color = "black", linewidth = 0.5)
  )

# ========== Combine and Save Figure ==========

# Combine the two panels into a single figure with lowercase bold labels
combined_figure <- p1 + p2 +
  plot_annotation(tag_levels = "a") &
  theme(
    plot.tag = element_text(size = 11, face = "bold", family = "Helvetica"),
    plot.background = element_rect(fill = "white", color = NA)
  ) +
  plot_layout(ncol = 2, widths = c(1.2, 1))

# Save as PDF (vector format) - double column width (180mm = ~7.09 inches)
ggsave(file.path(output_dir, "Figure_1.pdf"),
       combined_figure, 
       width = 180, 
       height = 90, 
       units = "mm",
       device = cairo_pdf)

# Also save high-res version for preview (optional)
ggsave(file.path(output_dir, "Figure_1_preview.png"),
       combined_figure, 
       width = 180, 
       height = 90, 
       units = "mm",
       dpi = 300)

ggsave(file.path(output_dir, "Figure_1.svg"),
       combined_figure, 
       width = 180, 
       height = 90, 
       units = "mm",
       device = "svg")



