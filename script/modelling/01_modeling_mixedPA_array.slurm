#!/bin/bash
#SBATCH --job-name=biomod_mix
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --partition=main
#SBATCH -A 					# EDIT: add your project ID here
#SBATCH --ntasks=1
#SBATCH --array=1-83			# EDIT: Adapt according to species number

# --- Load modules (CAREFUL: This is specific to Dardel cluster (KTH)---
module purge
module load PDCOLD/23.12
module load cpeGNU/23.12
module load R/4.4.1-cpeGNU-23.12
module load gdal/3.9.0-cpeGNU-23.12
module load proj/9.1.1
module load geos/3.9.1

# --- Set R library path ---
export R_LIBS_USER= 			# EDIT: add your custom library
export LD_LIBRARY_PATH=/opt/cray/pe/R/4.4.1/lib64/R/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/pdc/software/eb/software/proj/9.1.1/lib64:/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/lib64:$LD_LIBRARY_PATH
export PATH=/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/bin:$PATH
export RSTUDIO=0

# --- Go to working directory ---
cd 							# EDIT: add path to your current directory
mkdir -p logs

# --- pick species from the list by task id ---
species_list="species_list.txt"
SPECIES=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$species_list")
SPECIES_SAFE=$(echo "$SPECIES" | tr ' ' '_' | tr -d '\r')

# --- set log directory ---
LOGDIR="logs/${SPECIES_SAFE}"
mkdir -p "$LOGDIR"

# Redirect stdout and stderr to species-specific log files
exec >"$LOGDIR/${SPECIES_SAFE}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out" 2>"$LOGDIR/${SPECIES_SAFE}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}.err"

# --- Parameters ---
ALGORITHMS="RF,MAXNET,MARS,GAM,XGBOOST"
CV_STRATEGY="kfold"
CV_NB_REP=1
CV_PERC=""
CV_K=5
N_CORES=4
ENV="myExpl_shelf.tif"

# Distances in meters (20–100 km)
PA_DIST_MIN=20000
PA_DIST_MAX=100000

BASENAME=$(basename "$ENV" .tif)
OUTDIR="eval/${SPECIES}_mixed_${BASENAME}_${CV_STRATEGY}"
mkdir -p "$OUTDIR"

echo ">>> Running ${SPECIES} | MIX (disk+random) | ENV=${ENV} | CV=${CV_STRATEGY} | dmin=${PA_DIST_MIN} m | dmax=${PA_DIST_MAX} m"

# Launch R script
# CV repetitions (1 = single run of k-fold)
Rscript modeling_mixedPA.R \
  "$SPECIES" \
  "$ALGORITHMS" \
  "$PA_DIST_MIN" \
  "$PA_DIST_MAX" \
  "$CV_STRATEGY" \
  "$CV_NB_REP" \
  "$CV_PERC" \
  "$CV_K" \
  "$N_CORES" \
  "$ENV" \
  "$OUTDIR"
