# gemorna-utr-pred-nutshell

A Snakemake pipeline that wraps [GEMORNA](https://github.com/RainaBio/GEMORNA) for
**5'/3' UTR activity prediction**: given a user-supplied UTR sequence, run the matching
GEMORNA predictor (`main_pred5UTR.py` or `main_pred3UTR.py`) and report the score.
Built on the nutshell-pipeline-template standard, runs identically on a laptop or a
SLURM cluster, distributed as a slim Apptainer image bundling only the two predictor
checkpoints.

Sibling repos:
- [gemorna-cds-opt-nutshell](https://github.com/HeDScenter/gemorna-cds-opt-nutshell) — CDS codon optimization.
- [gemorna-utr-gen-nutshell](https://github.com/HeDScenter/gemorna-utr-gen-nutshell) — UTR generation (also scores generated UTRs in-line).

## Modes

| Goal | `mode` | `data/sequence.fa` contents |
|---|---|---|
| Score a 5' UTR | `5utr_pred` | the UTR(s), in FASTA |
| Score a 3' UTR | `3utr_pred` | the UTR(s), in FASTA |

## Quick start — score a 5' UTR

```bash
# 1. Create a run directory and add your UTR(s)
mkdir -p ~/runs/utr5_score/data
cd ~/runs/utr5_score
cat > data/sequence.fa <<'EOF'
>my_utr
GAGCUGGGAACUCCUGUGUUCUUACAGAGGUCAGCCCCUGGCGCC
EOF

# 2. Write config.yaml
cat > config.yaml <<'EOF'
common_parameters:
  mode: 5utr_pred
  random_seed: 42
EOF

# 3. Run (container mode)
SIF_PATH=/path/to/gemorna-utr-pred-nutshell.sif VENV=~/.venvs/gemorna-utr-pred-nutshell \
  /path/to/gemorna-utr-pred-nutshell/run_pipeline_local.sh

# Output: results/final_output.json — one row per UTR with predicted_activity.
```

## Runtime model

Same as the sibling repos: `PIPELINE_DIR` (this repo, bind-mounted read-only) + `RUN_DIR`
(per-analysis dir holding `config.yaml`, `data/`, `results/`, `logs/`). Snakemake runs on
the host; rules execute inside the container when `SIF_PATH` is set, or natively against
the on-host GEMORNA checkout (see `pipeline.local.yaml.example`).

## Provenance

This repo was split from [HeDScenter/gemorna-nutshell](https://github.com/HeDScenter/gemorna-nutshell)
on 2026-06-30. See `LICENSE` and `THIRD_PARTY_LICENSES.md` for attribution.
