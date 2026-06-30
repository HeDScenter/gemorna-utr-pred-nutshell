# Snakemake workflow for gemorna-nutshell
#
# This skeleton fans OUT over the sequences in the input FASTA (one job per
# sequence), then fans IN with a single concatenate step into one final table.
# Run locally:  ./run_pipeline_local.sh   |   On HPC:  sbatch run_pipeline.sh
#
# Need BATCHED (Slurm) compute — many sequences grouped into a capped number of
# jobs? That is intentionally stripped from this skeleton to keep it simple.
# See https://github.com/HeDScenter/2d-rnafold for the batching implementation.

import os

# Pipeline directory (where this Snakefile lives) — bind-mounted, never modified at runtime.
PIPELINE_DIR = os.path.dirname(os.path.abspath(workflow.snakefile))

# RUN_DIR anchors all per-run inputs/outputs. Both runners pass --directory $RUN_DIR,
# so the snakemake cwd at this point is the run directory. Don't rely on
# workflow.configfiles — Snakemake 9 keeps only the last --configfile when several
# are passed (e.g. a local override layered on top of the run's config.yaml).
config_dir = os.path.abspath(os.getcwd())

# Each subjob runs inside the Apptainer container when SIF_PATH is set.
# In native mode (e.g. desktop) SIF_PATH is unset and no container is used.
if os.environ.get("SIF_PATH"):
    container: os.environ["SIF_PATH"]

# ---------------------------------------------------------------------------
# Local-executor timeout backstop.
#
# Each rule declares a per-rule `runtime` (minutes). On SLURM this becomes
# `--time` and SLURM owns the kill. The local executor does NOT enforce
# `runtime`, so each rule wraps its command in GNU `timeout` as a safety net.
# The local `timeout` must fire STRICTLY LATER than SLURM, never before, or it
# would mask SLURM's handling. The grace factor pushes the local deadline past
# SLURM's so SLURM always wins. (`timeout` is GNU coreutils — keep it available
# in the container; see apptainer.def.)
# Seconds passed to `timeout` = runtime_minutes * 60 * TIMEOUT_GRACE_FACTOR.
# ---------------------------------------------------------------------------
TIMEOUT_GRACE_FACTOR = float(os.environ.get("TIMEOUT_GRACE_FACTOR", "1.5"))


def timeout_seconds(runtime_minutes):
    """Shell `timeout` value (seconds) — runtime plus grace so SLURM kills first."""
    return int(runtime_minutes * 60 * TIMEOUT_GRACE_FACTOR)

# ---------------------------------------------------------------------------
# Mode — must be resolved before FASTA discovery so we can stub for *_gen modes
# ---------------------------------------------------------------------------

_masked = config.get("masked_parameters", {})
_common = config.get("common_parameters", {})
_mode   = _common.get("mode", "cds")

# ---------------------------------------------------------------------------
# Discover sequences from the input FASTA at DAG-construction time
# ---------------------------------------------------------------------------


def _find_input_fasta(directory):
    """Return path to sequence.fa or sequence.fa.gz (whichever exists)."""
    for name in ("sequence.fa", "sequence.fa.gz"):
        path = os.path.join(directory, name)
        if os.path.exists(path):
            return path
    raise FileNotFoundError(f"No sequence.fa or sequence.fa.gz found in {directory}")


def _parse_fasta_ids(path):
    import gzip
    ids = []
    opener = gzip.open(path, "rt") if path.endswith(".gz") else open(path)
    with opener as fh:
        for line in fh:
            if line.startswith(">"):
                ids.append(line[1:].split()[0])
    return ids


try:
    _input_fasta = _find_input_fasta(
        os.path.join(config_dir, _masked.get("input_dir", "data"))
    )
    SEQUENCE_IDS = _parse_fasta_ids(_input_fasta)
except FileNotFoundError:
    raise

if not SEQUENCE_IDS:
    raise ValueError(f"No sequences found in {_input_fasta}")

# ---------------------------------------------------------------------------
# Mode dispatch — this repo ships 5'/3' UTR activity prediction.
# ---------------------------------------------------------------------------
PREDICT_MODES = {"5utr_pred", "3utr_pred"}

if _mode in PREDICT_MODES:
    include: os.path.join(PIPELINE_DIR, "modules/predict_utr.smk")
else:
    raise ValueError(
        f"gemorna-utr-pred-nutshell only supports modes {sorted(PREDICT_MODES)}, got {_mode!r}. "
        "CDS optimization → HeDScenter/gemorna-cds-opt-nutshell; "
        "UTR generation → HeDScenter/gemorna-utr-gen-nutshell."
    )

# ---------------------------------------------------------------------------
# Aggregate per-sequence results into one final table
# ---------------------------------------------------------------------------
_output_dir = os.path.join(config_dir, _masked.get("output_dir", "results"))
_output_ext = _masked.get("output_ext", "json.gz")
_all_results = [f"{_output_dir}/analyse/{sid}/result.tsv" for sid in SEQUENCE_IDS]

rule concatenate_results:
    input: _all_results
    output: os.path.join(_output_dir, f"final_output.{_output_ext}")
    params:
        script  = os.path.join(PIPELINE_DIR, "scripts/concatenate_results.py"),
        timeout = lambda wildcards, resources: timeout_seconds(resources.runtime),
    resources:
        mem_mb  = _masked.get("resources", {}).get("concatenate", {}).get("max_memory_gb", 4) * 1024,
        runtime = _masked.get("resources", {}).get("concatenate", {}).get("runtime", 30),
    threads: _masked.get("resources", {}).get("concatenate", {}).get("threads", 1)
    shell:
        "timeout {params.timeout} python '{params.script}' {input} --output '{output}'"

rule all:
    input: os.path.join(_output_dir, f"final_output.{_output_ext}")
