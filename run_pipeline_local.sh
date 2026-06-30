#!/bin/bash

# gemorna-utr-pred-nutshell Pipeline Runner - Local Execution
#
# DO NOT copy this script into RUN_DIR. Run it by its full path from RUN_DIR:
#
#   cd /path/to/runs/my_run/
#   /path/to/pipelines/gemorna-utr-pred-nutshell/run_pipeline_local.sh                 # native (no container)
#   SIF_PATH=/path/to/gemorna-utr-pred-nutshell.sif  .../run_pipeline_local.sh         # inside the container
#
# PIPELINE_DIR is resolved as the directory containing this script (native mode)
# or as dirname(SIF_PATH) when a container is used.
# RUN_DIR is resolved as the current working directory at execution time.
#
# Snakemake runs on the host. When SIF_PATH is set, each rule runs inside the
# Apptainer container; otherwise rules run natively (handy for the example step,
# which is pure Python). Parallelism is controlled by total_threads and
# total_max_memory_gb in config.yaml.
#
# Required in RUN_DIR:
#   - config.yaml
#   - data/sequence.fa  (FASTA)
#
# Optional environment variables:
#   - SIF_PATH: absolute path to gemorna-utr-pred-nutshell.sif (enables the container)
#   - VENV: path to a Python venv OR a conda/micromamba env containing snakemake
#     (venvs are sourced via bin/activate; conda/micromamba envs are activated
#     by prepending their bin/ to PATH, since they have no bin/activate)
#   - LIMA_INSTANCE: name of the Lima VM to use on macOS (default: "default")
#   - PIPELINE_LOCAL_CONFIG: path to a YAML that overrides masked_parameters
#     (e.g. checkpoints/, vocab_dir, gemorna_src). Layered after the run's
#     config.yaml so its values win. Required in native mode unless your
#     run config already supplies on-host paths. See pipeline.local.yaml.example.
#
# macOS note: Apptainer is not natively available on macOS. When SIF_PATH is set,
# this script routes Apptainer through a Lima VM via limactl.

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

RUN_DIR="$(pwd)"

USE_CONTAINER=false
if [ -n "${SIF_PATH:-}" ]; then
    USE_CONTAINER=true
    PIPELINE_DIR="$(dirname "$SIF_PATH")"
else
    # Native mode: PIPELINE_DIR is the directory containing this script.
    PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# ============================================================================
# macOS / Lima detection (only relevant when a container is used)
# ============================================================================

USE_LIMA=false
LIMA_INSTANCE="${LIMA_INSTANCE:-default}"

if $USE_CONTAINER && [ "$(uname -s)" = "Darwin" ]; then
    USE_LIMA=true
    echo "Detected macOS — Apptainer will be routed through Lima (limactl)."
fi

# ============================================================================
# Environment Setup
# ============================================================================

echo "=========================================="
echo "gemorna-utr-pred-nutshell Pipeline - Local Execution"
echo "=========================================="
echo "Run directory: $RUN_DIR"
echo "Pipeline directory: $PIPELINE_DIR"
echo "Container: ${SIF_PATH:-<none, native mode>}"
echo "Virtual env: ${VENV:-<none, using PATH>}"
if $USE_LIMA; then
    echo "Lima instance: $LIMA_INSTANCE"
fi
echo ""

if [ -n "${VENV:-}" ]; then
    if [ -f "$VENV/bin/activate" ]; then
        echo "Activating virtual environment: $VENV"
        # shellcheck disable=SC1091
        source "$VENV/bin/activate"
    elif [ -x "$VENV/bin/python" ]; then
        # micromamba/conda envs have no bin/activate; put their bin on PATH.
        echo "Activating conda/micromamba environment: $VENV"
        export PATH="$VENV/bin:$PATH"
        export CONDA_PREFIX="$VENV"
    else
        echo "ERROR: VENV does not look like a virtualenv or conda env: $VENV"
        exit 1
    fi
fi

echo "Checking dependencies..."

if $USE_CONTAINER; then
    if $USE_LIMA; then
        limactl --version > /dev/null 2>&1 || { echo "ERROR: limactl not found. Install Lima: https://lima-vm.io"; exit 1; }

        LIMA_STATUS=$(limactl list --format '{{.Name}} {{.Status}}' 2>/dev/null | awk -v inst="$LIMA_INSTANCE" '$1==inst{print $2}')
        if [ -z "$LIMA_STATUS" ]; then
            echo "ERROR: Lima instance '$LIMA_INSTANCE' does not exist."
            echo "Create one with: limactl start --name=$LIMA_INSTANCE template://apptainer"
            exit 1
        fi
        if [ "$LIMA_STATUS" != "Running" ]; then
            echo "ERROR: Lima instance '$LIMA_INSTANCE' is not running (status: $LIMA_STATUS)."
            echo "Start it with: limactl start $LIMA_INSTANCE"
            exit 1
        fi

        limactl shell "$LIMA_INSTANCE" apptainer --version > /dev/null 2>&1 \
            || { echo "ERROR: apptainer not found inside Lima instance '$LIMA_INSTANCE'"; exit 1; }

        # Create a wrapper so Snakemake finds "singularity"/"apptainer" on PATH
        WRAPPER_DIR="$(mktemp -d /tmp/lima-apptainer-wrapper.XXXXXX)"
        cat > "$WRAPPER_DIR/singularity" <<EOF
#!/bin/bash
exec limactl shell "$LIMA_INSTANCE" apptainer "\$@"
EOF
        chmod +x "$WRAPPER_DIR/singularity"
        ln -s "$WRAPPER_DIR/singularity" "$WRAPPER_DIR/apptainer"
        export PATH="$WRAPPER_DIR:$PATH"
        trap 'rm -rf "$WRAPPER_DIR"' EXIT

        echo "  ✓ limactl found, instance '$LIMA_INSTANCE' is running"
        echo "  ✓ apptainer available inside Lima"
    else
        apptainer --version > /dev/null 2>&1 || { echo "ERROR: apptainer not found"; exit 1; }
    fi

    if [ ! -f "$SIF_PATH" ]; then
        echo "ERROR: Container not found: $SIF_PATH"; exit 1
    fi
fi

snakemake --version > /dev/null 2>&1 || { echo "ERROR: snakemake not found (set VENV or activate the right environment)"; exit 1; }

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

TOTAL_THREADS=$(grep "total_threads:" "$RUN_DIR/config.yaml" | awk '{print $2}' || echo "1")
TOTAL_MEM_GB=$(grep "total_max_memory_gb:" "$RUN_DIR/config.yaml" | awk '{print $2}' || echo "8")
TOTAL_MEM_MB=$((TOTAL_MEM_GB * 1024))

echo "✓ config.yaml found"
echo "✓ Input file found: $INPUT_FILE"
echo "✓ Total threads (parallel jobs): $TOTAL_THREADS"
echo "✓ Total memory budget: ${TOTAL_MEM_GB}GB"
echo ""

# ============================================================================
# Run Pipeline
# ============================================================================

echo "Running gemorna-utr-pred-nutshell..."
echo "Start time: $(date)"
echo ""

cd "$RUN_DIR"

CONTAINER_ARGS=()
if $USE_CONTAINER; then
    CONTAINER_ARGS=(--use-apptainer --apptainer-args "--bind $RUN_DIR --bind $PIPELINE_DIR")
fi

# Optional override that layers on top of the run's config.yaml. In native
# mode this is how on-host GEMORNA paths replace the container's
# /opt/gemorna/* defaults; see pipeline.local.yaml.example.
# Snakemake 9's --configfile flag does not merge multiple files (the last
# one wins), so we deep-merge ourselves and pass a single combined file.
CONFIGFILE="$RUN_DIR/config.yaml"
if [ -n "${PIPELINE_LOCAL_CONFIG:-}" ]; then
    if [ ! -f "$PIPELINE_LOCAL_CONFIG" ]; then
        echo "ERROR: PIPELINE_LOCAL_CONFIG points at non-existent file: $PIPELINE_LOCAL_CONFIG"; exit 1
    fi
    MERGED_CONFIG="$(mktemp /tmp/gemorna-utr-pred-nutshell-config.XXXXXX.yaml)"
    trap 'rm -f "$MERGED_CONFIG"' EXIT
    python - "$RUN_DIR/config.yaml" "$PIPELINE_LOCAL_CONFIG" "$MERGED_CONFIG" <<'PY'
import sys, yaml
def deep_merge(base, override):
    for k, v in (override or {}).items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base
with open(sys.argv[1]) as f: base = yaml.safe_load(f) or {}
with open(sys.argv[2]) as f: ovr = yaml.safe_load(f) or {}
with open(sys.argv[3], "w") as f:
    yaml.dump(deep_merge(base, ovr), f, default_flow_style=False, sort_keys=False)
PY
    CONFIGFILE="$MERGED_CONFIG"
    echo "✓ Layered override config: $PIPELINE_LOCAL_CONFIG → $MERGED_CONFIG"
    echo ""
fi

snakemake all \
    --snakefile "$PIPELINE_DIR/Snakefile" \
    --configfile "$CONFIGFILE" \
    --directory "$RUN_DIR" \
    --jobs "$TOTAL_THREADS" \
    --resources mem_mb="$TOTAL_MEM_MB" \
    --rerun-incomplete \
    --keep-going \
    --printshellcmds \
    ${CONTAINER_ARGS[@]+"${CONTAINER_ARGS[@]}"} \
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
