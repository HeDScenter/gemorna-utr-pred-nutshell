#!/bin/bash
#SBATCH --job-name=ms-pipeline
#SBATCH --time=02:00:00
#SBATCH --mem=4G
#SBATCH --cpus-per-task=1
#SBATCH --account=your_account_here
#SBATCH --output=ms-pipeline_%j.log
#SBATCH --error=ms-pipeline_%j.err

# gemorna-utr-pred-nutshell Pipeline Runner - SLURM Job Script
#
# Submit from RUN_DIR, passing SIF_PATH (which must be in PIPELINE_DIR):
#
#   cd /path/to/runs/my_run/
#   sbatch --export=SIF_PATH=/path/to/pipelines/gemorna-utr-pred-nutshell/gemorna-utr-pred-nutshell.sif \
#          /path/to/pipelines/gemorna-utr-pred-nutshell/run_pipeline.sh
#
# PIPELINE_DIR is derived from dirname(SIF_PATH) — both must live in the same directory.
# RUN_DIR is resolved as the current working directory at submission time.
#
# Required in RUN_DIR:
#   - config.yaml
#   - data/sequence.fa  (FASTA)
#
# Required environment variable:
#   - SIF_PATH: absolute path to gemorna-utr-pred-nutshell.sif
#
# Optional environment variable:
#   - VENV: path to a Python virtual environment containing snakemake

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

RUN_DIR="$(pwd)"

# Pipeline directory: derived from SIF_PATH (both live in the same directory).
# Do NOT use ${BASH_SOURCE[0]} — SLURM copies the script to a spool dir.
if [ -z "${SIF_PATH:-}" ]; then
    echo "ERROR: SIF_PATH is not set."; exit 1
fi

PIPELINE_DIR="$(dirname "$SIF_PATH")"

# ============================================================================
# Environment Setup
# ============================================================================

echo "=========================================="
echo "gemorna-utr-pred-nutshell Pipeline - SLURM Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Run directory: $RUN_DIR"
echo "Pipeline directory: $PIPELINE_DIR"
echo "Container: $SIF_PATH"
echo "Virtual env: ${VENV:-<none, using PATH>}"
echo ""

echo "Loading modules..."
module load apptainer/1.4.5 2>/dev/null || true

if [ -n "${VENV:-}" ]; then
    echo "Activating virtual environment: $VENV"
    source "$VENV/bin/activate"
fi

echo "Checking dependencies..."
apptainer --version > /dev/null || { echo "ERROR: apptainer not found"; exit 1; }
snakemake --version > /dev/null || { echo "ERROR: snakemake not found (set VENV or load the right module)"; exit 1; }

if [ ! -f "$SIF_PATH" ]; then
    echo "ERROR: Container not found: $SIF_PATH"; exit 1
fi

# ============================================================================
# Validation
# ============================================================================

echo ""
echo "Validating configuration..."

if [ ! -f "$RUN_DIR/config.yaml" ]; then
    echo "ERROR: config.yaml not found in $RUN_DIR"; exit 1
fi

INPUT_DIR=$(grep -A5 "masked_parameters:" "$RUN_DIR/config.yaml" | grep "input_dir:" | awk '{print $2}' | tr -d '"' || echo "data")

if [ -f "$RUN_DIR/$INPUT_DIR/sequence.fa" ]; then
    INPUT_FILE="$RUN_DIR/$INPUT_DIR/sequence.fa"
elif [ -f "$RUN_DIR/$INPUT_DIR/sequence.fa.gz" ]; then
    INPUT_FILE="$RUN_DIR/$INPUT_DIR/sequence.fa.gz"
else
    echo "ERROR: Input file not found: $RUN_DIR/$INPUT_DIR/sequence.fa (.gz)"
    echo "Check your config.yaml input_dir setting (current: $INPUT_DIR)"
    exit 1
fi

echo "✓ config.yaml found"
echo "✓ Input file found: $INPUT_FILE"
echo ""

# ============================================================================
# Run Pipeline
# ============================================================================

echo "Running gemorna-utr-pred-nutshell..."
echo "Start time: $(date)"
echo ""

cd "$RUN_DIR"

APPTAINER_SUBJOB_ARGS="--bind $RUN_DIR --bind $PIPELINE_DIR"

snakemake all \
    --snakefile "$PIPELINE_DIR/Snakefile" \
    --configfile "$RUN_DIR/config.yaml" \
    --profile "$PIPELINE_DIR/slurm_profile" \
    --directory "$RUN_DIR" \
    --use-apptainer \
    --apptainer-args "$APPTAINER_SUBJOB_ARGS" \
    && EXIT_CODE=0 || EXIT_CODE=$?

echo ""
echo "=========================================="
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Pipeline completed successfully!"
    OUTPUT_DIR=$(grep 'output_dir:' "$RUN_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"')
    OUTPUT_EXT=$(grep 'output_ext:' "$RUN_DIR/config.yaml" | head -1 | awk '{print $2}' | tr -d '"' || echo "json.gz")
    echo "Results saved to: $RUN_DIR/$OUTPUT_DIR"
    echo "Final table:      $RUN_DIR/$OUTPUT_DIR/final_output.$OUTPUT_EXT"
else
    echo "✗ Pipeline failed with exit code: $EXIT_CODE"
fi
echo "End time: $(date)"
echo "=========================================="

exit $EXIT_CODE
