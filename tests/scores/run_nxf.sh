#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

bash ./tests/scores/setup.sh

scoredir=$(cat tests/scores/score_dir.txt)
scores="${scoredir}/*.txt.gz"

nextflow run main.nf \
    -ansi-log false \
    --input ./tests/scores/samplesheet_annot.csv \
    -c ./tests/config/score.config \
    --max_cpus 1 \
    --max_memory 16.GB \
    --target_build GRCh37 \
    --pgs_id PGS000018,PGS000027,PGS000049,PGS000137,PGS000337,PGS000904 \
    --keep_multiallelic false
