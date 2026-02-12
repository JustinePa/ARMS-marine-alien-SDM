# ========== Load Libraries ==========
library(terra)
library(ggplot2)
#install.packages("tidyterra", repos = "https://cloud.r-project.org/")
library(tidyterra)
library(biomod2)

# ========== Memory-Safe Settings ==========
tmp_dir <- file.path(getwd(), "tmp")
dir.create(tmp_dir, showWarnings = FALSE)
terraOptions(memfrac = 0.5, tempdir = tmp_dir)

# ========== Parse Command Line Args ==========
args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0) stop("? Please provide arguments.")
myRespName <- args[1]
modeling_id <- args[2]
n_cores <- as.integer(args[3])


# ========== Load Ensemble Model ==========

model_dir <- myRespName
model_file <- file.path(model_dir, paste(myRespName, modeling_id, "ensemble.models.out", sep = "."))

if (!file.exists(model_file)) {
  cat(paste0("Model file not found: ", model_file, "\n"))
  quit(status = 0)  # Exit normally so SLURM can continue to next task
}
myBiomodEM <- get(load(model_file))

# ========== Load Environmental Layers ==========
env_path <- "myExpl_shelf.tif"
if (!file.exists(env_path)) stop("? Environmental raster not found!")
myExpl <- rast(env_path)

# ========== Run Current Projection (if missing) ==========
proj_current_dir <- file.path(model_dir, paste0("proj_CurrentEM_", myRespName, "_", modeling_id))
current_outputs <- c(
  paste0("proj_CurrentEM_", myRespName, "_", modeling_id, "/", myRespName, "_ensemble.projection.out"),
  paste0("proj_CurrentEM_", myRespName, "_", modeling_id, "/", myRespName, "_ensemble.tif"),
  paste0("proj_CurrentEM_", myRespName, "_", modeling_id, "/", myRespName, "_ensemble_TSSbin.tif"),
  paste0("proj_CurrentEM_", myRespName, "_", modeling_id, "/", myRespName, "_ensemble_TSSfilt.tif"))
skip_current <- all(file.exists(current_outputs))

# what's available inside the ensemble object
avail <- biomod2::get_built_models(myBiomodEM)

# keep only TSS, regardless of species / merged suffixes
keep_em <- avail[grepl("(_EMwmeanByTSS|_EMcvByTSS|EMcaByTSS)(_|$)", avail)]

if (length(keep_em) == 0) {
  cat("No EMwmeanByTSS/EMcvByTSS/EMcaByTSS found for", my RespName, "— skipping.\n")
  quit(status = 0)
}

cat("Forecasting these ensemble types:\n"); print(keep_em)

myBiomodEMProj <- BIOMOD_EnsembleForecasting(
  bm.em         = myBiomodEM,
  proj.name     = paste0("CurrentEM_", myRespName, "_", modeling_id),
  new.env       = myExpl,
  models.chosen = keep_em,    # <-- full names like Arcuatulasenhousia_EMwmeanByTSS_mergedData_...
  nb.cpu        = n_cores,
  do.stack      = FALSE

)

