#!/usr/bin/env bash
set -euo pipefail
repo=$(cd "$(dirname "$0")/../.." && pwd)
run_dir=${V3_RUN_DIR:-"$repo/work/integration-v3"}
mkdir -p "$run_dir"
docker run --rm --network none --read-only --tmpfs /tmp \
  -v "$repo:/repo:ro" -v "$run_dir:/work" -w /work \
  "${V3_IMAGE:-pgsc_calc:v3-local}" bash -euc '
    if [ ! -f fixture/raw_score.txt.gz ]; then python /repo/tests/v3/fixture.py; fi
    pgsc_calc_workflow -c /repo/tests/v3/resources.config \
      --input /work/fixture/samplesheet.csv --scorefile /work/fixture/raw_score.txt.gz \
      --target_build GRCh38 --outdir /work/results -ansi-log false "$@"
    serial_dir=$(mktemp -d)
    pgsc_calc run --target_genomes \
      /work/fixture/chr1.batch0.vcf.gz:1 /work/fixture/chr1.batch1.vcf.gz:1 \
      /work/fixture/chr2.batch0.vcf.gz:2 /work/fixture/chr2.batch1.vcf.gz:2 \
      --sampleset prototype --format vcf --score_paths /work/fixture/score.txt.gz \
      --threads 1 --max_memory_gb 1 --out_dir "$serial_dir"
    cp "$serial_dir/scores.txt.gz" /work/serial-scores.txt.gz
    python /repo/tests/v3/compare.py
    test -s results/report.html
    test -s results/genotypes.zarr.zip
    test -z "$(find results -name "*.parquet" -print -quit)"
  ' bash "$@"
