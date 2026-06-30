#!/bin/bash
#
# gemorna-utr-pred-nutshell — native macOS wrapper around run_pipeline_local.sh
#
# Sets the two environment variables required for native (no-container)
# execution on macOS, then delegates to run_pipeline_local.sh:
#
#   VENV                  -> Python 3.10 micromamba env so GEMORNA's libg2m
#                            (compiled against 3.10) loads cleanly
#   PIPELINE_LOCAL_CONFIG -> overrides the container's /opt/gemorna/* paths
#                            with the on-host GEMORNA checkout
#
# Usage (from a RUN_DIR containing config.yaml and data/sequence.fa):
#
#   cd /path/to/runs/my_run/
#   /path/to/gemorna-utr-pred-nutshell/run_gemorna_mac.sh
#
# Any environment variables already set in the caller's shell win over the
# defaults below, so you can override either path without editing this file:
#
#   VENV=/path/to/other/env  /path/to/gemorna-utr-pred-nutshell/run_gemorna_mac.sh

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${VENV:=$HOME/micromamba/envs/gemorna}"
: "${PIPELINE_LOCAL_CONFIG:=$PIPELINE_DIR/pipeline.local.yaml}"

export VENV PIPELINE_LOCAL_CONFIG

exec bash "$PIPELINE_DIR/run_pipeline_local.sh" "$@"
