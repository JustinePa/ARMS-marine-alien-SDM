# ========== Load Libraries ==========
library(terra)
library(ggplot2)
library(tidyterra)
library(biomod2)

# ========== Memory-Safe Settings ==========
dir.create("/cfs/klemming/home/p/pagnier/tmp", showWarnings = FALSE)
terraOptions(memfrac = 0.5, tempdir = "/cfs/klemming/home/p/pagnier/tmp")

# ========== Parse Command Line Args ==========
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("? Args: <species> <modeling_id> <n_cores>")
myRespName  <- args[1]
modeling_id <- args[2]
n_cores     <- as.integer(args[3])

# ========== Set working directory ==========
setwd("")

# ========== Load Ensemble Model ==========
model_dir  <- myRespName
model_file <- file.path(model_dir, paste(myRespName, modeling_id, "ensemble.models.out", sep = "."))
if (!file.exists(model_file)) {
  cat("! Ensemble models file not found: ", model_file, "\n", sep = "")
  quit(status = 0)  # exit cleanly so SLURM array continues
}

loaded_name <- load(model_file)
myBiomodEM  <- get(loaded_name, inherits = FALSE)
if (!inherits(myBiomodEM, "BIOMOD.ensemble.models.out")) {
  stop("Loaded object is not a BIOMOD.ensemble.models.out: ", loaded_name)
}

# ========== Load Reference Environmental Layers ==========
env_path <- "myExpl_shelf_DISTFIX.tif"
if (!file.exists(env_path)) stop("? Environmental raster not found: ", env_path)
myExpl <- rast(env_path)

# ========== Which ensemble flavours to use ==========
avail   <- biomod2::get_built_models(myBiomodEM)
keep_em <- avail[grepl("(_EMwmeanByTSS|_EMcvByTSS)(_|$)", avail)]
if (length(keep_em) == 0) {
  cat("! No EMwmeanByTSS/EMcvByTSS flavours found — skipping species.\n")
  quit(status = 0)
}
cat("▶ Ensemble flavours to forecast:\n")
print(keep_em)

# ========== Run Future Projections ==========
scenarios <- c("ssp585")

for (scenario in scenarios) {
  proj_name       <- paste0(scenario, "EM_", myRespName, "_", modeling_id)
  proj_future_dir <- file.path(model_dir, paste0("proj_", proj_name))
  env_path_future <- file.path(paste0(scenario, "_layers_extrap_2100_shelf_DISTFIX_2.tif"))

  if (!file.exists(env_path_future)) {
    cat("! Missing env for ", scenario, ": ", env_path_future, " — skipping this scenario.\n", sep = "")
    next
  }

  myExpl_future <- rast(env_path_future)

  # strict check: band names must match current env
  if (!identical(names(myExpl_future), names(myExpl))) {
    stop("Layer names/order mismatch for ", scenario, ".\nCurrent: ",
         paste(names(myExpl), collapse = ", "),
         "\nFuture:  ", paste(names(myExpl_future), collapse = ", "))
  }

  cat("\n🚀 Running Future Ensemble Forecasting: ", myRespName, " | ", scenario, " | cores=", n_cores, "\n", sep = "")
  tryCatch({
    myBiomodEMProj_Future <- BIOMOD_EnsembleForecasting(
      bm.em         = myBiomodEM,
      proj.name     = proj_name,
      new.env       = myExpl_future,
      models.chosen = keep_em,
      nb.cpu        = n_cores,
      do.stack      = FALSE
    )
    cat("✔ Done: ", scenario, "\n", sep = "")
  }, error = function(e) {
    cat("✖ Failed: ", scenario, " — ", conditionMessage(e), "\n", sep = "")
  })
}

cat("\n✅ Done! Projections are in: ", normalizePath(model_dir, winslash = "/"), "\n", sep = "")
