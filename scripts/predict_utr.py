#!/usr/bin/env python3
"""Wrapper: per-sequence predictor for 5' or 3' UTR. Writes one-row result.tsv.

Output schema:
    sequence_id, utr_seq, predicted_activity
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

COLUMNS = ["sequence_id", "utr_seq", "predicted_activity"]


def write_tsv(row: dict, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w") as fh:
        fh.write("\t".join(COLUMNS) + "\n")
        fh.write("\t".join(str(row.get(c, "NA")) for c in COLUMNS) + "\n")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--input", required=True, type=Path, help="Run-dir FASTA")
    p.add_argument("--seq-id", required=True, help="The {seq_id} wildcard")
    p.add_argument("--mode", required=True, choices=["5utr_pred", "3utr_pred"])
    p.add_argument("--ckpt-path", required=True)
    p.add_argument("--output-dir", required=True, type=Path)
    p.add_argument(
        "--gemorna-cli",
        default="/opt/gemorna/src/main_pred5UTR.py",
        help="Path to the predictor script (defaults to 5UTR; override for 3UTR)",
    )
    args = p.parse_args()

    from Bio import SeqIO

    record = next(
        (r for r in SeqIO.parse(args.input, "fasta") if r.id == args.seq_id), None
    )
    if record is None:
        sys.exit(f"sequence_id {args.seq_id!r} not in {args.input}")
    seq = str(record.seq)

    with tempfile.TemporaryDirectory() as tmp:
        single_fa = Path(tmp) / "one.fa"
        single_fa.write_text(f">{args.seq_id}\n{seq}\n")
        out_jsonl = Path(tmp) / "score.jsonl"
        r = subprocess.run(
            [
                sys.executable,
                args.gemorna_cli,
                "--ckpt_path",
                args.ckpt_path,
                "--input-fasta",
                str(single_fa),
                "--output-file",
                str(out_jsonl),
            ],
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            sys.exit(f"predictor failed (rc={r.returncode}):\n{r.stderr}")
        rec = json.loads(out_jsonl.read_text().splitlines()[0])

    write_tsv(
        {
            "sequence_id": rec["sequence_id"],
            "utr_seq": rec["sequence"],
            "predicted_activity": f"{rec['predicted_activity']:.4f}",
        },
        args.output_dir / args.seq_id / "result.tsv",
    )


if __name__ == "__main__":
    main()
