#!/usr/bin/env bash
# Throwaway offline integration demo. Run from any directory.
set -euo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd)
run_dir="$repo/work/prototype-v3"
mkdir -p "$run_dir"
docker run --rm --network none \
  -v "$repo:/repo:ro" -v "$run_dir:/work" -w /work \
  pgscatalog/pgsc_calc:v3-blob bash -euc '
    prototype=/repo/workflows/pgsc_calc/prototype_v3
    if [ ! -f fixture/samplesheet.csv ]; then python "$prototype/fixture.py"; fi
    nextflow -C "$prototype/nextflow.config" run "$prototype/main.nf" \
      --input /work/fixture/samplesheet.csv --scorefile /work/fixture/score.txt.gz \
      --outdir /work/results -ansi-log false "$@"
    serial_dir=$(mktemp -d)
    pgsc_calc run --target_genomes \
      /work/fixture/chr1.batch0.vcf.gz:1 /work/fixture/chr1.batch1.vcf.gz:1 \
      /work/fixture/chr2.batch0.vcf.gz:2 /work/fixture/chr2.batch1.vcf.gz:2 \
      --sampleset prototype --format vcf --score_paths /work/fixture/score.txt.gz \
      --threads 1 --max_memory_gb 1 --out_dir "$serial_dir"
    cp "$serial_dir/scores.txt.gz" /work/serial-scores.txt.gz
    python "$prototype/compare.py"
  ' bash "$@"
