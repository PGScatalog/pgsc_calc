# Throwaway v3 scoring prototype

Question: can Nextflow dispatch the pinned Python scoring stages at their intended
partition boundaries and reproduce serial scoring, including pooled imputation,
inside one offline container?

Run from the repository root:

```bash
bash workflows/pgsc_calc/prototype_v3/run.sh
```

To resume the Nextflow tasks:

```bash
bash workflows/pgsc_calc/prototype_v3/run.sh -resume
```

The launcher mounts this checkout read-only and uses `--network none`. Nextflow
runs locally inside `pgscatalog/pgsc_calc:v3-blob`; tasks invoke the installed
Python tools directly. There are no nested containers, plugin downloads or
runtime environment solves. The production workflow is unchanged.

The synthetic fixture has 60 samples, two chromosomes and two sample batches:
four LOAD tasks, two MATCH tasks, one MATCH_COMBINE task, four SCORE tasks and one
SCORE_COMBINE task. One batch has no fully called alleles at a matched variant;
its imputation frequency must come from the other batch. Each batch has only
30 samples, so the example also exercises the sampleset-wide imputation floor.

The launcher compares all final fields with a fresh Python serial run and checks
scores against simple arithmetic. Missing calls are imputed in the score but do
not increase `allele_count`: the first 30 samples have six observed alleles and
the other 30 have eight. Output is under `work/prototype-v3/`:

- `results/scores.txt.gz`: final scores.
- `results/logs/`: matching summary and variant logs.
- `serial-scores.txt.gz`: reference output from Python serial scoring.
- `trace.tsv`: task boundaries, caching and measured resources.
- `fixture/`: disposable generated input; remove this directory to regenerate it.
- `work/`: intermediate caches, Parquet files and task logs.

## Validation recorded on 10 November 2026

A fresh offline run completed all 12 tasks. All 60 rows matched Python serial
scoring, and the independent arithmetic assertions passed. No Parquet files were
published. A subsequent resume reused all 12 tasks successfully.
The fresh trace is retained as `work/prototype-v3/trace-fresh.tsv`.
The local arm64 image was the multi-platform image index
`sha256:75341cbadbba61c4d9b01dd8f2f2cfda1625afe41ec108ff1c0b474be9eddf25`,
built from Python commit `9aa7015eb1a46af9e2f88fbb03baeb25a89dbbe7`.
The image tag is mutable, so repeat these checks after updating it.

## Findings

The pinned CLI requires integer `--max_memory_gb` values. Each stage receives
one thread and a 1 GiB application limit from a 2 GiB Nextflow allocation. These
are application settings, not a guarantee of total process memory.

SCORE still needs `--score_paths` in addition to the gated `--match_table`.
Archives and intermediate files with identical basenames must be staged into
separate numbered directories. The cache leaf names inside archives must remain
unchanged. MATCH groups all sample batches by chromosome; MATCH_COMBINE is a
single barrier and its table is reused by every SCORE task.

**Resolved Python limitation in the original image:** LOAD used bcftools `--exclude-uncalled`. A site
whose calls are all `./.` in one VCF batch is dropped, making the cache ragged;
MATCH then rejects it before imputation. The fixture follows the upstream test
by including one partial `0/.` call: it retains the site but contributes no
allele counts under whole-call missingness. This is not a workaround to apply to
real data.

Python commit `3753260d5628b139ab0f6890dbb238056127d625` retains these sites.
The rebuilt multi-platform image index is
`sha256:54f1e17764afe8050b8aa5f37a0559bb6020abce17cd326e82e7a0f76be32ccb`.
A fresh offline run with genuinely all-`./.` calls completed all 12 tasks;
all 60 samples matched serial scoring and independent arithmetic. Results are in
`work/prototype-v3-fixed-image/`. That run replaced the partial call in the
generated fixture; the fixture generator above still contains the original case.
Regenerate affected caches: the fix cannot recover sites dropped by an older LOAD.

## Agreed production behavior

On 10 November 2026, the user accepted the following empty-shard rule:
skip an irrelevant chromosome shard, but fail explicitly if dropping a shard
would remove required samples from scoring. An empty LOAD output alone does not
prove that the shard is irrelevant. The integration must establish that distinction
before omitting it. This rule is not yet implemented in the production workflow.

Unified-cache publication remains enabled by default (`publish_cache = true`).
The extra archive assembly I/O and temporary storage are accepted to encourage
cache reuse and reduce CPU usage in future runs. Users can disable publication
explicitly; Nextflow's intermediate caches remain available for resume either way.

When cache publication is enabled, failure to assemble or publish the unified
archive fails the overall run. Completed scoring and report outputs remain
available, but their presence does not indicate a successful run. After the
underlying problem is corrected, resume should reuse completed tasks and retry
the failed cache work.

Cache reuse validates file metadata rather than hashing entire genotype files.
Record the size in bytes and modification time at the highest available resolution
for each genotype file, its index, and its optional BGEN sample file. Compare
these values before reusing that shard's cache, alongside existing shard identity
checks. Directory paths may change without invalidating the cache.

A metadata mismatch rejects reuse and requires fresh caching. The error must
identify the shard and file, show the recorded and current metadata values, and
explain how to run without the incompatible cache and publish a replacement.
Do not silently fall back to rebuilding. This check deliberately accepts that
changed content with identical size and preserved timestamps can go undetected;
unchanged copies with different timestamps are rejected. Implementation is pending.

Caches using an unsupported version, including older caches without the required
input metadata, are rejected without migration or fallback. Use this error:
"Unsupported cache version. Run without `--genotype_cache_zip` to create a new cache."

When new scoring files require additional positions, reuse the existing cached
genotypes and load the additional positions from the original inputs. Leave the
supplied archive unchanged. With cache publication enabled, write an expanded
archive containing existing and newly loaded data to the new results directory.
The extra disk space and copying are accepted to preserve the original cache if
the run fails and to allow concurrent runs to share it safely. After a successful
run, users can use the expanded archive and remove the old copy if no longer needed.

The user will test 500,000 samples and 80,000,000 variants and provide feedback
from those runs. These figures describe the planned test dataset, not a verified
capacity or a per-shard size. Dataset partitioning and score count are unspecified.
Preparation of those large-scale runs remains with the user. Local integration
checks can proceed without waiting for further sizing details.

## Boundaries of this prototype

This is an autosomal VCF vertical slice, not the completed alpha.2 integration.
It accepts preformatted scoring files, canonical chromosome labels and one
sampleset; it checks duplicate cache leaves and rejects unsupported absence
semantics. It exposes matching flags, but the automated comparison uses the
fixture's default settings. LOAD outputs are required: an empty cache fails
rather than silently dropping a shard.

Still to implement or validate: BGEN, formatting and liftover, chromosome alias
normalisation, whole-genome input, `sex_map` and sex-check publication, deliberate
empty-shard handling, cache assembly/reuse and compatibility checks, HTML report
adaptation, release metadata, larger resource measurements and HPC/TRE acceptance.
Intermediate Parquet files remain private; variant logs are currently published
as directories rather than a zip archive. This prototype mounts the workflow;
it does not bake the updated workflow into a release image.

After the task graph and interfaces are accepted, absorb them into the production
modules and remove this prototype. Do not maintain a second scoring workflow.
