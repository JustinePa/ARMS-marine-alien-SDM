# Figure Generation Scripts

## Overview

These scripts generate publication-ready figures from processed species distribution modeling results, including model performance analyses, habitat suitability maps, and climate change projections.

## Scripts

1. **Figure_1.r** - Model performance analysis (TSS/AUC vs occurrence sample size)
2. **Figure_2.r** - Species-level habitat suitability maps with uncertainty (current conditions)
3. **Figure_3.r** - Habitat suitability changes (current vs SSP 2-4.5)
4. **Figure_4.r** - Cumulative habitat suitability map (invasion hotspots)
5. **Figure_5.r** - Changes in cumulative suitability across climate scenarios (SSP 1-2.6, 2-4.5, 5-8.5)
6. **Figure_6.R** - Ecoregion-level analysis (percentage and absolute changes in habitat suitability)

Each script is self-contained and generates a single publication figure.

## Requirements

```r
install.packages(c("terra", "ggplot2", "sf", "rnaturalearth", 
                   "dplyr", "tidyr", "patchwork", "ggpubr",
                   "grid", "gridExtra", "reshape2"))
```

## Input Data

These scripts require:
- **Biomod2 model outputs** (habitat suitability projections)
- **Model diagnostics** (TSS, AUC values)
- **MEOW ecoregions shapefile** (for Figure 6)

File paths are hardcoded and should be updated to match your data directory structure.

## Output

Each script generates:
- High-resolution PDF figure (publication-ready)
- Figures saved to species-specific output directories

## Figure Descriptions

### Figure 1: Model Performance
Two-panel figure showing:
- TSS and AUC values vs occurrence sample size
- Standard deviation decrease with sample size

### Figure 2: Example Species Maps
Three-panel maps for selected species showing:
- Habitat suitability (current conditions)
- Coefficient of variation (EMcv)
- Committee averaging uncertainty (EMca)

### Figure 3: Suitability Changes
Maps showing habitat suitability transitions between current and future (SSP 2-4.5):
- Suitable → Unsuitable
- Unsuitable → Suitable
- Persistently suitable/unsuitable

### Figure 4: Invasion Hotspots
Cumulative habitat suitability map showing areas suitable for multiple invasive species (current conditions).

### Figure 5: Future Changes
Three-panel figure showing changes in cumulative habitat suitability under different climate scenarios (SSP 1-2.6, 2-4.5, 5-8.5).

### Figure 6: Ecoregion Analysis
Bar charts comparing:
- Percentage change in habitat suitability by ecoregion
- Absolute change in habitat suitability by ecoregion
Across all three SSP scenarios.

## Notes

- Figures use European extent: longitude -28° to 70°, latitude 28° to 83°
- Color schemes optimized for publication and colorblind accessibility
- Detailed methods and interpretations are provided in the associated publication

## Contact

Justine Pagnier  
University of Gothenburg  
justine.pagnier@gu.se
