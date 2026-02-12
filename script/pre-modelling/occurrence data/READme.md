## Occurrence Data Pipeline

Scripts: `pre-modelling/occurrence data/01` through `04`

These scripts download, merge, and spatially thin species occurrence records
from GBIF and OBIS for all 69 non-indigenous species in the study. The final
output is a set of spatially thinned presence files used as input to the
species distribution modelling pipeline.

>  **The thinned occurrence files used in the published analysis are
> archived on [[Figshare](https://figshare.com/s/ab27e1dcaee11ba59e88)]. If you only want to reproduce the models or figures,
> you can download these directly and skip to the modelling pipeline.**
> Re-running this pipeline requires GBIF credentials and an active internet
> connection, and will download data reflecting current GBIF/OBIS holdings
> rather than the snapshot used in the published analysis.

### Prerequisites

- [ ] R 4.4.1 with the following packages installed:
      `rgbif`, `robis`, `spThin`, `dplyr`, `lubridate`
- [ ] A GBIF account (free registration at [gbif.org](https://www.gbif.org))
- [ ] `species_list.csv` in your working directory, with a column named `Species`
- [ ] All scripts run from the same working directory

### Pipeline overview
```
01_get_gbif_data.R      → occurrences_0825/*_gbif_occurrences_2025-08-19.csv
02_get_obis_data.R      → occurrences_0825/*_obis_occurrences_2025-08-19.csv
03_merge_both.R         → occurrences_0825/occurrences_merged/*_merged_2025-08-19.csv
04_thinning.R           → occurrences_thinned_0825/*_merged_thinned_2025-08-19.csv
```

Scripts must be run sequentially. Scripts 01 and 02 can be run in any order
relative to each other, but both must complete before running script 03.

> ⚠️ **Output filenames include the download date (`2025-08-19` for the
> published analysis).** This date is hardcoded in scripts 03 and 04 via
> the `output_date` variable. If you re-run scripts 01 and 02 on a
> different date, update `output_date` in scripts 03 and 04 to match.

---

### Script 01: Download GBIF occurrence data

Downloads presence records from GBIF for each species in `species_list.csv`,
applying filters for coordinate quality, basis of record, and date range
(2000–2025). Skips species files that already exist.

**Filtering criteria:**
- No geospatial issues
- Coordinate uncertainty < 5000m (or unspecified)
- Basis of record: human observation, machine observation, material sample,
  occurrence, observation
- Date range: 2000-01-01 to 2025-08-01

**Output:** `occurrences_0825/*_gbif_occurrences_{date}.csv`

>  Downloads are asynchronous — the script submits a request to GBIF
> and waits for it to be prepared before downloading. Processing time
> varies with species record count and GBIF queue length.

---

### Script 02: Download OBIS occurrence data

Downloads presence records from OBIS for each species in `species_list.csv`,
applying filters for basis of record, date range, and coordinate completeness.
Skips species files that already exist.

**Filtering criteria:**
- Basis of record: HumanObservation, Occurrence, MaterialSample
- Date range: 2000-01-01 to 2025-08-01
- Complete, valid coordinates

**Output:** `occurrences_0825/*_obis_occurrences_{date}.csv`

>  No credentials required for OBIS. Downloads are synchronous and
> may take several minutes for species with large occurrence datasets.

---

### Script 03: Merge GBIF and OBIS records

Combines GBIF and OBIS occurrence files for each species, removes duplicate
coordinates across sources, and saves a merged file. Produces a summary CSV
reporting record counts per species and per source. Works even if a species
has data from only one source.

**Inputs:** `occurrences_0825/*_gbif_occurrences_2025-08-19.csv`,
`occurrences_0825/*_obis_occurrences_2025-08-19.csv`

**Outputs:**
- `occurrences_0825/occurrences_merged/*_merged_2025-08-19.csv`
- `occurrences_0825/occurrences_merged/merged_summary_2025-08-19.csv`

> ⚠️ The `output_date` variable at the top of this script must match
> the date in the filenames produced by scripts 01 and 02. For the
> published analysis this is `"2025-08-19"`.

---

### Script 04: Spatial thinning

Applies spatial thinning (10 km minimum distance between points) to reduce
sampling bias in presence records. Designed to run as a SLURM array job,
with each task processing one species file independently.

**Thinning parameters:**
- Distance threshold: 10 km
- Algorithm: `spThin` (Aiello-Lammens et al. 2015)
- Repetitions: 1 (reproducible via species-specific seed)

**Input:** `occurrences_0825/occurrences_merged/*_merged_2025-08-19.csv`

**Outputs:**
- `occurrences_thinned_0825/*_merged_thinned_2025-08-19.csv`
- `occurrences_thinned_0825/thinning_summary_{species}.csv` (one per species)

**To run as a SLURM array job**, submit with:
```bash
#SBATCH --array=1-69   # adjust to number of species
Rscript 04_thinning.R $SLURM_ARRAY_TASK_ID
```

**To run locally** (sequentially, without SLURM):
```r
for (i in 1:69) {
  system(paste("Rscript 04_thinning.R", i))
}
```

> ⚠️ The `output_date` variable in this script must match the date used
> in scripts 01–03. For the published analysis this is `"2025-08-19"`.

>  Per-species summary files (`thinning_summary_{species}.csv`) are
> written separately to avoid race conditions during parallel execution.
> Merge them after the run with:
> ```r
> files <- list.files("occurrences_thinned_0825",
>                     pattern = "^thinning_summary_.*\\.csv$",
>                     full.names = TRUE)
> summary <- dplyr::bind_rows(lapply(files, read.csv))
> write.csv(summary, "occurrences_thinned_0825/thinning_summary.csv",
>           row.names = FALSE)
> ```

---

### Troubleshooting

- **GBIF download times out:** Increase the `status_ping` interval in
  `occ_download_wait()` or re-run — completed downloads are skipped
  automatically.
- **Species not found in GBIF/OBIS:** Check that the species name in
  `species_list.csv` matches the accepted name in the respective database.
  Some species may require synonym resolution.
- **Date mismatch errors in script 03 or 04:** Ensure `output_date` matches
  the actual download date in filenames. Check filenames in
  `occurrences_0825/` if unsure.
- **Thinning returns fewer points than expected:** `spThin` is stochastic
  even with a fixed seed when record counts are very high. Results are
  reproducible given the same input data and seed, but may differ if
  occurrence data are re-downloaded.
