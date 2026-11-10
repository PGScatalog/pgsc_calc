# pgscatalog/pgsc_calc

[![GitHub Actions CI Status](https://github.com/pgscatalog/pgsc_calc/actions/workflows/nf-test.yml/badge.svg)](https://github.com/pgscatalog/pgsc_calc/actions/workflows/nf-test.yml)[
![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.5970794-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.5970794)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.04.0-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-3.4.1-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https%3A%2F%2Fnf-co.re)](https://github.com/nf-core/tools/releases/tag/3.4.1)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/pgscatalog/pgsc_calc)

## Introduction

`pgsc_calc` is a bioinformatics best-practice analysis pipeline for calculating
polygenic [risk] scores on samples with imputed genotypes using existing scoring
files from the [Polygenic Score (PGS) Catalog](https://www.pgscatalog.org/)
and/or user-defined PGS/PRS.


## v3-alpha.2 integration candidate

This candidate replaces plink2 scoring with the Python `pgscatalog.calc` stages.
It accepts one sampleset per run, including technical sample batches and
chromosome partitions in VCF or BGEN format. Missing calls use allele frequencies
pooled across the sampleset. Scoring files with X or Y variants require an explicit
sex map; ploidy comes from the observed calls.

The supported launch runs bundled Nextflow and its tasks inside one offline image.
Local validation is described in [the offline guide](docs/docs/howto/offline-v3.md).
HPC/TRE acceptance remains pending. Standalone Conda and cross-node execution are
outside the candidate's validated scope.

## Pipeline summary

* Format local Catalog or custom scoring files, with local liftover chains when needed.
* Load each target shard and validate sample coverage.
* Match all technical batches for each chromosome, then apply `min_overlap` across the sampleset.
* Score each shard and combine its contributions into final scores.
* Publish matching logs, sex-check TSVs, an HTML report and an optional unified cache.

Prepare Catalog downloads before offline execution. The existing online download
interface is retained for other launch modes.

### PGS applications and libraries

`pgsc_calc` uses applications and libraries internally developed at the PGS Catalog, which can do helpful things like:

* Query the PGS Catalog to bulk download scoring files in a specific genome build
* Match variants from scoring files to target variants
* Adjust calculated PGS in the context of genetic ancestry

If you want to write Python code to work with PGS, [check out the `pygscatalog` repository to learn more](https://github.com/PGScatalog/pygscatalog).

If you want a simpler way of working with PGS, ignore this section and continue below to learn more about `pgsc_calc`.

## Quick start

Follow the [offline launch and validation guide](docs/docs/howto/offline-v3.md) to
build the local candidate or run a published candidate image with local analysis
inputs. Nextflow, its plugin and all task tools are bundled; no host Nextflow
installation or nested container engine is needed.

The image publication step is separate from local validation. Use the published
candidate digest for HPC/TRE acceptance, and retain the writable work directory
for `-resume`.

## Documentation

See the [alpha.2 offline guide](docs/docs/howto/offline-v3.md) for the launch model,
samplesheet declarations, sex maps, cache compatibility and test commands.

## Credits

pgscatalog/pgsc_calc is developed as part of the PGS Catalog project, a
collaboration between the University of Cambridge’s Department of Public Health
and Primary Care (Michael Inouye, Samuel Lambert) and the European
Bioinformatics Institute (Helen Parkinson, Laura Harris).

The pipeline seeks to provide a standardized workflow for PGS calculation and
ancestry inference implemented in nextflow derived from an existing set of
tools/scripts developed by Inouye lab (Rodrigo Canovas, Scott Ritchie, Jingqin
Wu) and PGS Catalog teams (Samuel Lambert, Laurent Gil).

The adaptation of the codebase, nextflow implementation, and PGS Catalog features
are written by Benjamin Wingfield, Samuel Lambert, Laurent Gil with additional input
from Aoife McMahon (EBI). Development of new features, testing, and code review
is ongoing including Inouye lab members (Rodrigo Canovas, Scott Ritchie) and others. If 
you use the tool we ask you to cite our paper describing software and updated PGS Catalog resource:

- >Lambert, Wingfield _et al._ (2024) Enhancing the Polygenic Score Catalog with tools for score 
  calculation and ancestry normalization. Nature Genetics.
  doi:[10.1038/s41588-024-01937-x](https://doi.org/10.1038/s41588-024-01937-x).

This pipeline is distrubuted under an [Apache License](LICENSE) amd uses code and 
infrastructure developed and maintained by the [nf-core](https://nf-co.re) community 
(Ewels *et al. Nature Biotech* (2020) doi:[10.1038/s41587-020-0439-x](https://doi.org/10.1038/s41587-020-0439-x)), 
reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

Additional references of open-source tools and data used in this pipeline are described in
[`CITATIONS.md`](CITATIONS.md).

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.
[10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
