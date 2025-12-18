# ========== Load Libraries ==========
library(biomod2)
library(PRROC)
library(dplyr)
library(terra)
library(tidyr)

# ========== Parse Command Line Args ==========
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("Please provide arguments: <species> <modeling_id>")
myRespName  <- args[1]
modeling_id <- args[2]

# ========== Directories ==========
base_dir   <- "/cfs/klemming/home/p/pagnier/biomod_pipeline/0.test_method"
output_dir <- file.path(base_dir, "EM_mix50")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)


# ========== Load Biomod Object ==========
model_file <- file.path(base_dir, myRespName, paste(myRespName, modeling_id, "models.out", sep = "."))
if (!file.exists(model_file)) stop("Model file not found: ", model_file)

loaded_name <- load(model_file)
myBiomodModelOut <- get(loaded_name)

cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "1"))

# ========== Ensemble Modeling ==========
myBiomodEM <- BIOMOD_EnsembleModeling(
  bm.mod        = myBiomodModelOut,
  models.chosen = "all",
  em.by         = "all",
  em.algo       = c("EMwmean", "EMcv", "EMca"),
  EMwmean.decay = "proportional",
  metric.select = c("TSS","ROC"),
  metric.select.thresh = c(0.6, 0.85),  
  metric.eval   = c("TSS","ROC"),
  var.import    = 0,
  nb.cpu        = cores
)

# ========== Save ensemble evaluation ==========
em_eval <- as.data.frame(get_evaluations(myBiomodEM))
write.csv(em_eval,
          file = file.path(output_dir, paste0("full_eval_EM_", myRespName, "_", modeling_id, ".csv")),
          row.names = FALSE)

cat("✅ Done with ensemble for", myRespName, "\n")
