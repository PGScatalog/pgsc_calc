# Run the alpha.2 candidate offline

The alpha.2 launch model runs bundled Nextflow and its tasks inside one image,
using the local executor. Run the image on one host or inside one allocated HPC
job. Cross-node scheduler dispatch and standalone Conda installations have not
been validated for this candidate.

The image includes the workflow, Python tools, report tools, Nextflow and its
pinned schema plugin. Supply analysis data separately: indexed VCF or BGEN files,
BGEN sample files, local scoring files, any liftover chains, and a sex map when
scoring files contain X or Y variants. Catalog downloads are rejected offline.

```bash
mkdir -p work results
docker run --rm --network none \
  -v "$PWD/input:/input:ro" \
  -v "$PWD/work:/work" -v "$PWD/results:/results" -w /work \
  pgscatalog/pgsc_calc:v3-alpha.2 \
  pgsc_calc_workflow --input /input/samplesheet.csv \
  --scorefile '/input/scores/*.txt.gz' --target_build GRCh38 \
  --outdir /results
```

Use the candidate's published digest for reproducibility. The release image is
not published by the local integration checks; `v3-alpha.2` above names the
intended candidate tag. Keep the work directory and add `-resume` to restart a
run. Set CPU and memory allocations with a mounted Nextflow configuration (`-c`).
Each Python stage receives its task CPUs and an integer memory limit with 25%
headroom. These settings do not guarantee peak process memory.

An Apptainer installation can convert the same published image before entering a
restricted environment:

```bash
apptainer pull pgsc_calc-v3-alpha.2.sif docker://pgscatalog/pgsc_calc:v3-alpha.2
apptainer exec --bind "$PWD/input:/input:ro,$PWD/work:/work,$PWD/results:/results" \
  --pwd /work pgsc_calc-v3-alpha.2.sif pgsc_calc_workflow \
  --input /input/samplesheet.csv --scorefile '/input/scores/*.txt.gz' \
  --target_build GRCh38 --outdir /results
```

The conversion follows the [Apptainer build interface](https://apptainer.org/user-docs/master/build_a_container.html).
Apptainer conversion and deployment acceptance remain to be tested on the target
HPC/TRE systems. No task launches another container or solves an environment.

## Inputs and outputs

Exactly one sampleset is accepted. Technical batches of one callset may share its
label; independently called cohorts need separate runs. The optional
`absent_variants` samplesheet column answers: **What does it mean when a variant
is absent from this file?** The only supported value is `unobserved` (the default).
Conflicting declarations and `homref` fail before processing.

Chromosome aliases are canonicalised; an empty chromosome or `ALL` means unsplit
input. A sampleset/chromosome/genotype-filename combination must be unique.
Provide `--sex_map` as a tab-separated file with `sample_id` and `sex` headers:
`0` unknown, `1` male, `2` female. Every genotyped sample needs a declaration when
X or Y scoring variants are present. The declaration checks observed calls; it
does not assign ploidy.

Final outputs are scores, matching summaries, variant match logs, an HTML report,
shard-specific sex-check TSVs when produced, and the optional unified cache.
Intermediate Parquet files stay in the work directory. Missing calls use pooled
sampleset allele frequencies; the 50-sample imputation floor applies across all
technical batches together.

## Cache reuse

Cache publication is enabled by default. Use `--publish_cache false` to disable
it. Archive assembly preserves each shard and does not combine genotype arrays.
An archive assembly or publication failure fails the run; other completed outputs
may remain. Correct the problem and resume the same work directory.

Use `--genotype_cache_zip` to reuse a compatible alpha.2 archive. LOAD checks each
original genotype file, its index and its BGEN sample file using byte size and
modification time. Paths may change. A metadata mismatch requires a fresh cache;
there is no fallback or migration from unsupported versions. This check cannot
detect changed content with identical size and preserved timestamps, and rejects
unchanged copies whose timestamps differ.

New scoring positions are loaded from the original inputs into a new cache.
The supplied archive stays unchanged, and enabled publication writes the expanded
archive into the new results directory. Keep the original archive until the run
has succeeded. Empty LOAD shards are omitted only after checking that all required
samples remain represented; a run without usable caches fails explicitly.

## Local checks

Build an unpublished local candidate from the existing runtime and the pinned
Python checkout (the Python commit must be available locally):

```bash
docker build --network none \
  --build-context python=/path/to/pygscatalog/pgscatalog.utils/packages/pgscatalog.calc \
  --build-arg PYGSCATALOG_COMMIT=61ba47b0d115fbbb4707ea81983713d6f077a683 \
  -f tests/v3/Dockerfile -t pgsc_calc:v3-local .
```

This validation image reuses the previously built runtime. The main Dockerfile
builds the complete runtime from source; its Python commit must be pushed before
CI can fetch it. Publishing remains a separate step.

Run `python -m unittest discover -s tests/v3 -v` for archive and empty-shard
validation. `bash tests/v3/run.sh` runs the production workflow with networking
disabled, including formatting and HTML reporting, then compares scores against
serial Python and independent pooled-imputation arithmetic. `V3_IMAGE` selects
the image and `V3_RUN_DIR` selects a fresh evidence directory. Add `-resume` to
check task reuse. The fixture has 60 samples in four shards and includes an
all-missing site in one sample batch; this is not a production capacity test.

Run `tests/v3/matrix.py` inside the same image with the checkout mounted at
`/repo` and the completed test directory at `/work`. It checks whole-genome VCF,
BGEN, irrelevant and required empty shards, cache reuse/expansion, source metadata,
unsupported caches, sex declarations and strand-flip settings. Evidence is saved
as individual logs and Nextflow traces. Use the same mounts to run
`tests/v3/rejections.py` for samplesheet validation before processing.
