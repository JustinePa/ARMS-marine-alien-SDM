#!/bin/bash
#SBATCH --job-name=projection
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=4
#SBATCH --partition=memory
#SBATCH -A 					# project ID
#SBATCH --ntasks=1

# --- Load required modules ---
module purge
module load PDCOLD/23.12
module load cpeGNU/23.12
module load R/4.4.1-cpeGNU-23.12
module load gdal/3.9.0-cpeGNU-23.12
module load proj/9.1.1
module load geos/3.9.1

# --- Set custom R library path (Dardel/PDC specific — adapt for your cluster) --- 
export R_LIBS_USER= 			# custom library path
export LD_LIBRARY_PATH=/opt/cray/pe/R/4.4.1/lib64/R/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/pdc/software/eb/software/proj/9.1.1/lib64:/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/lib64:$LD_LIBRARY_PATH
export PATH=/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/bin:$PATH

# Prevent R from assuming RStudio
export RSTUDIO=0

# Move to working directory
cd 							# Add your working directory

# --- Species name ---
SPECIES="Bugulaneritina"  # <-- Change to the species you're projecting
SPECIES_SAFE=$(echo $SPECIES | tr ' ' '_' | tr -d '\r')

# --- Which ensemble? How many cores? ---
MODELING_DATE="2025-09-24"  # must match the date used in step 1
BASENAME="myExpl_shelf"     # must match the env file used in step 1
CV_STRATEGY="kfold"         # must match step 1
MODELING_ID="${MODELING_DATE}_mix50_${CV_STRATEGY}_${BASENAME}"

N_CORES=4

echo "Running projections for: $SPECIES_SAFE, with ensemble from $MODELING_ID"

# --- Launch the R script ---
mkdir -p 1.logs/EM
Rscript --no-save --no-restore 03_projection_EM.R "$SPECIES_SAFE" "$MODELING_ID" "$N_CORES" > 1.logs/EM/future_projection_${SPECIES_SAFE}_${MODELING_ID}.out 2> 1.logs/EM/future_projection_${SPECIES_SAFE}_${MODELING_ID}.err
