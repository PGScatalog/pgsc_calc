# Alpha.2 local integration validation

Validated on 10 November 2026. The production Nextflow integration is implemented
on `v3-alpha.2`. The evidence below was collected locally before publication.
This is a locally validated integration
candidate, not a released or HPC/TRE-accepted build.

## Sources and image

- Python source: `61ba47b0d115fbbb4707ea81983713d6f077a683`, committed and pushed on
  `codex/pooled-allele-frequencies`. This adds source metadata validation and LOAD
  sample manifests to the previously tested pooled-imputation implementation.
- Validation runtime base: multi-platform digest
  `sha256:54f1e17764afe8050b8aa5f37a0559bb6020abce17cd326e82e7a0f76be32ccb`.
- Final local image: `pgsc_calc:v3-local`, arm64, image identity
  `sha256:3427524cc79f0f7693a63c5766b9320f16ff9422afde22fcc9ca9b3e07e74d92`.
  This identity is local, not a published registry candidate.
- `tests/v3/Dockerfile` copies the exact local Python source and production
  workflow into the existing runtime. The main `Dockerfile` instead builds from
  the source commit and bundles the workflow, tools, Nextflow 25.10.0 and
  nf-schema 2.4.2. Quarto is pinned to the tested 1.11.9 build.

## Results

The synthetic fixture has 60 samples in two technical batches and two
chromosomes. Each batch has 30 samples. A variant is entirely uncalled in one
batch and obtains its imputation frequency from the other batch.

The production baseline contains 16 tasks: FORMAT, four LOADs, sample coverage
validation, cache assembly, two MATCH tasks, MATCH_COMBINE, four SCORE tasks,
SCORE_COMBINE and REPORT. All 60 final rows match fresh serial Python scoring and
independent arithmetic, including observed allele counts. No intermediate
Parquet files appear in the results directory.

The final image completed all 16 tasks with networking disabled and its root
filesystem read-only. A subsequent resume cached all 16 tasks without submitting
new work. Nextflow state and report caches use writable work/task directories;
no task launches another container engine or solves an environment.

Additional production checks passed:

- Whole-genome VCF and BGEN reproduce partitioned scores and matching summaries.
- An irrelevant chromosome shard is omitted without losing samples; required
  sample loss and no usable caches fail explicitly.
- Unified-cache reuse reproduces scores and summaries. Additional scoring
  positions expand the new archive and produce the expected scores while leaving
  the supplied archive byte-for-byte unchanged.
- Input metadata mismatches and unsupported cache versions fail clearly.
- Mixed-ploidy X scoring produces the expected scores and allele counts (10 for
  hemizygous samples, 20 for diploid samples in the ten-variant fixture).
  Sex-check TSVs are published under unique sampleset/chromosome/shard paths.
  Missing and contradictory sex declarations fail.
- Strand-flipped matching is allowed by default and excluded when requested.
  All three matching flags are accurately represented in the HTML report.
- A local GRCh37-to-GRCh38 chain shifts the synthetic coordinates by ten bases
  and reproduces the baseline scores. This also verifies `--liftover` is enabled
  when a chain is staged.
- Nine early rejection cases start no processing tasks: multiple samplesets,
  duplicate canonical cache leaves, conflicting declarations, `homref`, invalid
  chromosomes 0 and 27, overwriting the supplied cache, offline Catalog downloads
  and remote analysis inputs.
- Three focused helper tests cover archive assembly, duplicate leaves,
  inconsistent ancestor metadata and empty-shard sample coverage. JSON parsing,
  shell syntax and `git diff --check` pass.

The Python cache change separately passed a 51-test integration selection and an
11-test cache selection, including actual BGEN genotype/index/sample metadata,
cache expansion, unchanged source archives and empty/multiple-target manifests.

## Evidence and reproduction

See [the offline guide](docs/howto/offline-v3.md) for image construction and launch
commands. From the repository root:

```bash
python -m unittest discover -s tests/v3 -v
bash tests/v3/run.sh
bash tests/v3/run.sh -resume
```

`tests/v3/matrix.py` and `tests/v3/rejections.py` run inside the image with this
checkout at `/repo` and the completed test directory at `/work`.

Recorded local evidence:

- `work/candidate-v3/`: layout, cache, empty-shard, sex and matching-option runs.
- `work/candidate-final-readonly/`: final read-only execution, serial comparison,
  liftover and report-flag runs, early rejections, and resume logs.
- `work/candidate-final-readonly/results/pipeline_info/execution_trace_2026-11-10_14-18-03.txt`:
  16 completed tasks on the final image.
- `work/candidate-final-readonly/results/pipeline_info/execution_trace_2026-11-10_14-18-33.txt`:
  16 cached tasks.
- `work/candidate-final-readonly/results/report.html`: final rendered report.

Earlier failing iterations are retained in the work directories as diagnostic
evidence. They exposed and led to fixes for Quarto environment paths, writable
runtime state, sex-check publication and liftover activation.

## Remaining release work

The main Dockerfile's Python commit has been pushed. The image workflow publishes
the `v3-alpha.2` tag and records the workflow commit on branch pushes. Successful
publication must be checked separately from the local validation recorded here.

The Python packages still report their alpha.1 distribution versions. Before the
actual package release, update the relevant package versions and workspace lock,
build from the resulting source commit, and repeat the candidate checks. The
integration candidate above identifies its exact runtime source by commit.

A fresh native amd64/arm64 build from the full Dockerfile, SIF creation and
Apptainer execution remain unverified. Apptainer/Singularity is not installed in
this local environment, so no SIF artifact was produced. The guide supplies the
conversion and launch commands for the eventual immutable candidate image.

HPC/TRE acceptance and the user's planned 500,000-sample / 80,000,000-variant runs
remain with the user's team. The tiny fixture and its resource measurements do
not establish production capacity. Standalone Conda/Mamba installation and
cross-node scheduler dispatch remain outside the agreed alpha.2 scope.

The original prototype and its decision record are preserved. The
production workflow and `tests/v3/` now contain its scoring and regression checks;
the prototype is not used by the bundled image.
