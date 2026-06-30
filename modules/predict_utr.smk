# Per-sequence UTR prediction rule (mode = 5utr_pred or 3utr_pred).

import os

PIPELINE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(workflow.snakefile)))
SCRIPT_PATH = os.path.join(PIPELINE_DIR, "scripts/predict_utr.py")

_masked = config.get("masked_parameters", {})
_common = config.get("common_parameters", {})

_mode = _common["mode"]
_pred_ckpt = _masked["checkpoints"]["utr5_pred" if _mode == "5utr_pred" else "utr3_pred"]
_pred_script_name = "main_pred5UTR.py" if _mode == "5utr_pred" else "main_pred3UTR.py"
_pred_script = os.path.join(_masked.get("gemorna_src", "/opt/gemorna/src"), _pred_script_name)

output_dir = os.path.join(config_dir, _masked.get("output_dir", "results")) if config_dir else "results"
log_dir = os.path.join(config_dir, "logs") if config_dir else "logs"

rule run_predict_utr:
    input:
        _input_fasta
    output:
        f"{output_dir}/analyse/{{seq_id}}/result.tsv"
    params:
        script      = SCRIPT_PATH,
        mode        = _mode,
        out_dir     = f"{output_dir}/analyse",
        ckpt        = _pred_ckpt,
        gemorna_cli = _pred_script,
        timeout     = lambda wildcards, resources: timeout_seconds(resources.runtime),
    resources:
        mem_mb  = _masked.get("resources", {}).get("predict_utr", {}).get("max_memory_gb", 4) * 1024,
        runtime = _masked.get("resources", {}).get("predict_utr", {}).get("runtime", 30),
    threads: _masked.get("resources", {}).get("predict_utr", {}).get("threads", 1)
    log:
        f"{log_dir}/run_predict_utr/{{seq_id}}.log"
    shell:
        """
        mkdir -p {params.out_dir} $(dirname {log})
        timeout {params.timeout} \
        python '{params.script}' \
            --input '{input}' \
            --seq-id {wildcards.seq_id} \
            --mode {params.mode} \
            --ckpt-path '{params.ckpt}' \
            --output-dir '{params.out_dir}' \
            --gemorna-cli '{params.gemorna_cli}' \
            > {log} 2>&1
        """
