#!/bin/bash
#SBATCH --job-name=ensemble_model
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=6
#SBATCH --partition=main
#SBATCH -A 			# Add your project name
#SBATCH --ntasks=1
#SBATCH --array=1-83  	# Adjust this based on your species list length

# --- Load modules ---
module purge
module load PDCOLD/23.12
module load cpeGNU/23.12
module load R/4.4.1-cpeGNU-23.12
module load gdal/3.9.0-cpeGNU-23.12
module load proj/9.1.1
module load geos/3.9.1

# --- Environment variables ---
export R_LIBS_USER=  		# add path to custom libraries
export LD_LIBRARY_PATH=/opt/cray/pe/R/4.4.1/lib64/R/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=/pdc/software/eb/software/proj/9.1.1/lib64:/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/lib64:$LD_LIBRARY_PATH
export PATH=/pdc/software/23.12/eb/software/gdal/3.9.0-cpeGNU-23.12/bin:$PATH

# Prevent R from assuming RStudio
export RSTUDIO=0

# --- Go to project directory ---
cd 						# Add you project directory path

# --- Get species from species_list.txt ---
species_list="species_list.txt"
SPECIES=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$species_list")
SPECIES_SAFE=$(echo "$SPECIES" | tr ' ' '_' | tr -d '\r')

# --- Which ensemble? ---
MODELING_ID=""			# fill the modeling id

echo "Running ENSEMBLE model for species: $SPECIES_SAFE, with runs from $MODELING_ID"

# --- Run the R script ---
mkdir -p 1.logs/EM
Rscript --no-save --no-restore ensemble.R "$SPECIES_SAFE" "$MODELING_ID" > 1.logs/EM/ensemble_${SPECIES_SAFE}_${MODELING_ID}.out 2> 1.logs/EM/ensemble_${SPECIES_SAFE}_${MODELING_ID}.err
