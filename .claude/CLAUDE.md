# gemorna-nutshell — Pipeline Developer Guide

A **Snakemake pipeline** that integrates one method (`<METHOD>`) over an input
FASTA and produces a single results table. Built from `nutshell-pipeline-template`.
Designed to run two ways from the *same* Snakefile:

- **SLURM** (HPC): `snakemake all --profile slurm_profile` — one Slurm job per unit of work.
- **Local** (the `<pipeline>-nutshell` microservice on a VM): the local executor,
  inside the Apptainer container (`SIF_PATH` set), no Slurm.

The same rules must behave correctly under **both** executors. That dual target is the
source of most rules below.

## The two pipeline shapes

Every micro-service is one of two fan-out shapes. The template ships the first;
the Snakefile documents how to switch to the second. Pick one and keep its invariants.

| Shape | Fan-out | Example tools | Output key |
|---|---|---|---|
| **Analyse** (shipped) | one job **per sequence** | RNAfold | `seq_id` |
| **Improve / optimise** | one job **per seed** (`i = 1..n_repeat`) | DNAChisel, VaxPress | `i` |

Both fan **in** through a single `concatenate_results` step into `results/final_output.<ext>`.

## Layout

```
Snakefile                       # entry: timeout_seconds(), discovery/fan-out, rule all/concatenate
modules/<step>.smk              # the per-unit rule (shell:)  ← edit for your tool
scripts/<step>.py               # the method step             ← write your tool here
scripts/concatenate_results.py  # generic aggregator (format from output_ext)
config.yaml                     # masked/common/advanced parameters
config.schema.yaml              # schema consumed by <pipeline>-nutshell to build the UI
tests/test_config.py            # config <-> schema validation
slurm_profile/                  # HPC profile (config_example.yaml)
apptainer.def / *.sif           # container image used in local mode
```

## Foundations (the standard that keeps micro-services interoperable)

- **Clean, boring code.** Many people use and extend these pipelines. Prefer clear
  code over clever code; name things for what they are. Match the surrounding style;
  comment the *why*, not the *what*. Keep the layout above standard.
- **Every module and script starts with an I/O contract comment** (paths + columns):
  - **Input:** `data/sequence.fa` — FASTA, plain or gzip; record IDs are unique.
  - **Per-run output:** `results/<step>/<key>/result.tsv` — one folder per sequence
    (or per seed), each a one-row TSV whose first column is `sequence_id`.
  - **Final output:** `results/final_output.<ext>` — every per-run row stacked, format
    from `masked_parameters.output_ext`. If you change a step's columns, update both
    the script's contract comment and `scripts/concatenate_results.py` (`OUTPUT_FIELDS`).
- **`shell:` rules only.** Do **not** use `run:` or `script:` — `run:` executes in the
  master process (won't run inside the per-rule container) and breaks HPC execution.
- **Anchor paths explicitly:** `PIPELINE_DIR` (this repo, bind-mounted, read-only at
  runtime) vs `config_dir` (the RUN_DIR holding `config.yaml`, `data/`, `results/`,
  `logs/`). Inputs/outputs live under `config_dir`; scripts under `PIPELINE_DIR`.
- **Config = three sections.** Keep the *structure*; the parameters are method-specific
  and differ by audience, not by being generic:
  - `masked_parameters` — paths + `resources`; hidden from end-users (integrator-set).
  - `common_parameters` — basic, must-answer knobs; shown by default.
  - `advanced_parameters` — expert knobs; available to all but masked by default.
  Validate `config.yaml` against `config.schema.yaml` (`tests/test_config.py`).

## Hard rules (a change that breaks one of these is a regression)

1. **Executor parity.** Every rule must run correctly under both SLURM and the local
   executor. Don't add anything that assumes one (e.g. Slurm-only env vars in a shell).
2. **`runtime` is per-rule, in minutes.** Each rule declares its own `runtime` resource,
   read from `masked_parameters.resources.<step>` (`mem_mb`, `runtime`, `threads`).
   Never introduce a single global timeout — rules have different cost profiles.
3. **Timeout = local backstop, SLURM wins.** The local executor does **not** enforce
   `runtime`, so each rule wraps its command in GNU `timeout` as a safety net. On SLURM,
   `runtime` becomes `--time` and SLURM owns the kill — so the shell `timeout` must fire
   **strictly later** than SLURM. That margin is `TIMEOUT_GRACE_FACTOR` (default 1.5) via
   `timeout_seconds()` in the Snakefile. Any new timed rule must use `timeout_seconds(...)`
   (passed as a `params.timeout`, computed `lambda wildcards, resources: timeout_seconds(resources.runtime)`),
   never raw `runtime * 60`. `timeout` exits 124 on expiry → the rule fails (logged;
   `--keep-going` spares the other units).
4. **`coreutils` must stay in the container.** The shell `timeout` is GNU coreutils.
   It comes from the base image in the `.sif` today — if you change `apptainer.def`,
   keep `timeout` available (verify with `apptainer exec <sif> which timeout`).
5. **The container is set globally** via `container: os.environ["SIF_PATH"]`; when
   `SIF_PATH` is unset the pipeline runs natively (e.g. the pure-Python example step).
6. **Keep your shape's invariants.**
   - *Analyse (per-sequence):* fan-out is one job per `seq_id`; `concatenate_results`
     depends on every per-sequence `result.tsv`.
   - *Improve/optimise (per-seed):* run the **same input `n_repeat` times** with a
     per-repeat seed offset (`base_seed + i - 1`) so repeats are reproducible yet
     distinct; don't collapse them to one seed. Stochastic tools fail occasionally —
     set `retries` in the SLURM profile and make `rule all` depend on the concatenated
     output, not on every repeat succeeding, so one bad draw doesn't sink the run.
7. **Method domain logic stays in the pipeline**, not in the `<pipeline>-nutshell`
   backend (that backend is pipeline-agnostic). Cost models, organism/codon mapping,
   tool-specific flags, etc. live **here** (`modules/<step>.smk` / `scripts/<step>.py`).
8. **Per-rule logs are a contract.** Rules write `{run_dir}/logs/<rule>/<key>.log`.
   `<pipeline>-nutshell` serves these via `/jobs/{id}/tasks/...`. Don't rename/relocate
   the log path without updating the backend that reads it.
9. **The schema is the UI contract.** `config.schema.yaml` drives the `<pipeline>-nutshell`
   form, and the backend reads `masked_parameters` defaults from it. Renaming/removing a
   parameter or its `default` changes the UI — update both sides together.
   Its top-level `version:` field is the release source of truth: read by nutshell-core's
   `get_pipeline_version()` and stamped into each job's `job_meta.json` for result
   provenance, and `.github/workflows/tag-on-version-bump.yml` tags `vX.Y.Z` when it
   changes on `main` — so **bumping it cuts a release**. Keep it equal to the latest
   release tag; change it only when you intend to release. Don't remove it (the backend
   tolerates absence as `null`, but results then lose provenance).
10. **The final-output path is a contract.** `<pipeline>-nutshell` reads
    `results/final_output.<ext>` directly. Don't change the name/format/location without
    updating the backend that reads it.

## Interaction with `<pipeline>-nutshell`

The backend generates the run's `config.yaml` (injecting values such as the resource
reservation) and reads back per-rule logs and the final output. Treat the config keys,
the log paths, and the output path as a **shared interface** — changing them here is a
breaking change there.

## Checklist for any pipeline change

- [ ] Rule works under **both** SLURM and local executors.
- [ ] Any timeout uses `timeout_seconds(resources.runtime)` via a `params.timeout`, not raw arithmetic.
- [ ] New shell tools exist in the container (or added to `apptainer.def`).
- [ ] Shape invariants preserved (per-sequence fan-out, or per-seed repeats + retries).
- [ ] Method-specific tuning stays in the pipeline, not pushed to the backend.
- [ ] Log/output paths and `config.schema.yaml` unchanged — or the backend updated to match.
- [ ] Verified with a dry-run (`snakemake all -n -p`) showing the resolved commands (incl. the `timeout` prefix).

## Out of scope

Batched (Slurm) compute — grouping many sequences into a capped number of jobs — is
intentionally **not** in this template, to keep it simple. See
https://github.com/HeDScenter/2d-rnafold for the batching implementation. The
FastAPI/Vue wrapper (`<pipeline>-nutshell`) is a separate project.
