#!/usr/bin/env python3
"""
Collect per-sequence result.tsv files into a single summary file.

Each input TSV contains one header row and one data row produced by a
per-step script (generate_cds.py, generate_utr.py, predict_utr.py). This
script stacks all inputs and infers the output columns from the union of
headers across all input files (preserving first-seen order). The result is written in the
format inferred from the output file extension:
  json / json.gz   — JSON array
  csv  / csv.gz    — comma-separated
  tsv  / tsv.gz    — tab-separated

Usage (standalone):
    python scripts/concatenate_results.py \\
        results/analyse_SEQ1/result.tsv \\
        results/analyse_SEQ2/result.tsv \\
        ... \\
        --output results/final_output.json.gz

Usage (Snakemake script: directive):
    The script reads snakemake.input and snakemake.output[0] automatically.
"""

import csv
import gzip
import json
import os
import sys


# ── Fieldname inference ────────────────────────────────────────────────────────

def _infer_fieldnames(tsv_files):
    """Return the union of column headers across all input TSVs.

    Preserves first-seen order across the sorted list of files. Raises
    ValueError if no file yields a non-empty header (so the pipeline doesn't
    silently produce an empty result file)."""
    seen = []
    seen_set = set()
    for path in sorted(tsv_files):
        try:
            with open(path, newline="") as fh:
                header = next(csv.reader(fh, delimiter="\t"), [])
        except FileNotFoundError:
            continue
        for col in header:
            if col not in seen_set:
                seen.append(col)
                seen_set.add(col)
    if not seen:
        raise ValueError("No input result.tsv files have a header")
    return seen


# ── Parser ─────────────────────────────────────────────────────────────────────

def parse_result_tsv(path):
    rows = []
    try:
        with open(path, newline="") as fh:
            reader = csv.DictReader(fh, delimiter="\t")
            for row in reader:
                rows.append(row)
    except FileNotFoundError:
        pass
    return rows


# ── Writer helpers ─────────────────────────────────────────────────────────────

def _open_text(path, newline=None):
    if path.endswith(".gz"):
        return gzip.open(path, "wt")
    return open(path, "w", newline=newline)


def _write_json(records, path):
    with _open_text(path) as out:
        json.dump(records, out, indent=2)


def _write_delimited(records, path, delimiter, fieldnames):
    with _open_text(path, newline="") as out:
        writer = csv.DictWriter(out, fieldnames=fieldnames, delimiter=delimiter)
        writer.writeheader()
        writer.writerows(records)


def _ext(path):
    """Return the logical extension, stripping a trailing .gz first."""
    base = path[:-3] if path.endswith(".gz") else path
    return os.path.splitext(base)[1].lstrip(".")


# ── Aggregation ────────────────────────────────────────────────────────────────

def process(tsv_files, output_path):
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    fieldnames = _infer_fieldnames(tsv_files)
    records = []
    for tsv_file in sorted(tsv_files):
        rows = parse_result_tsv(tsv_file)
        if not rows:
            print(f"WARNING: no data rows in {tsv_file}", file=sys.stderr)
            continue
        for row in rows:
            records.append({col: row.get(col, "") for col in fieldnames})

    ext = _ext(output_path)
    if ext == "json":
        _write_json(records, output_path)
    elif ext == "csv":
        _write_delimited(records, output_path, ",", fieldnames)
    elif ext == "tsv":
        _write_delimited(records, output_path, "\t", fieldnames)
    else:
        raise ValueError(f"Unsupported output extension: {ext!r}")


# ── Entry points ───────────────────────────────────────────────────────────────

# Snakemake script: directive passes a `snakemake` object into globals()
if "snakemake" in dir():
    process(list(snakemake.input), snakemake.output[0])  # noqa: F821
elif __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "tsv_files",
        nargs="+",
        help="result.tsv files, one per analyse run directory",
    )
    parser.add_argument("--output", required=True, help="Path for the output file")
    args = parser.parse_args()
    process(args.tsv_files, args.output)
