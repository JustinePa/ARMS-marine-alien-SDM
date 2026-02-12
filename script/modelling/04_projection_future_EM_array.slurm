#!/bin/bash
#SBATCH --job-name=projection_EM
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --partition=main   # or memory, adapt to your cluster
#SBATCH -A 						# Project ID
#SBATCH --ntasks=1
#SBATCH --array=1-69				# Adapt according to your number of species

# --- Load required modules ---
module purge
module load PDCOLD/23.12
module load cpeGNU/23.12
module load R/4.4.1-cpeGNU-23.12
module load gdal/3.9.0-cpeGNU-23.12
module load proj/9.1.1
module load geos/3.9.1

# Set custom R library path
export R_LIBS_USER= 				# custom library path
export LD_LIBRARY_PATH=/opt/cray/pe/R/4.4.1/lib64/R/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/pdc/software/eb/software/proj/9.1.1/lib64:/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/lib64:$LD_LIBRARY_PATH
export PATH=/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/bin:$PATH

# Prevent R from assuming RStudio
export RSTUDIO=0

# Move to working directory
cd 								# add your working directory

# --- Get species from species_list.txt ---
species_list="species_list_ensemble.txt"
SPECIES=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$species_list")
SPECIES_SAFE=$(echo "$SPECIES" | tr ' ' '_' | tr -d '\r')

# --- Which ensemble? How many cores? ---
MODELING_DATE="2025-09-24"
BASENAME="myExpl_shelf"
CV_STRATEGY="kfold"
MODELING_ID="${MODELING_DATE}_mix50_${CV_STRATEGY}_${BASENAME}"

N_CORES=4

echo "Running projections for: $SPECIES_SAFE, with ensemble from $MODELING_ID"

# --- Launch the R script ---
mkdir -p 1.logs/EM
Rscript --no-save --no-restore projection_EM_future.R "$SPECIES_SAFE" "$MODELING_ID" "$N_CORES" > 1.logs/EM/future_projection_${SPECIES_SAFE}_${MODELING_ID}.out 2> 1.logs/EM/future_projection_${SPECIES_SAFE}_${MODELING_ID}.err
