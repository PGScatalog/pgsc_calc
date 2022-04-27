# `pgsc_calc`: PGS Catalog Calculator

:rotating_light: This pipeline is stable, but represents a very minimal implementation :rotating_light:

:rotating_light: Please see the documentation for [important limitations](https://pgscatalog.github.io/pgsc_calc/) :rotating_light:

[![Documentation](https://github.com/PGScatalog/pgsc_calc/actions/workflows/docs.yml/badge.svg)](https://pgscatalog.github.io/pgsc_calc/index.html)
[![pgscatalog/pgsc_calc CI](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml/badge.svg)](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml)
[![nf-core linting](https://github.com/PGScatalog/pgsc_calc/actions/workflows/linting.yml/badge.svg)](https://github.com/PGScatalog/pgsc_calc/actions/workflows/linting.yml)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

`pgsc_calc` is a bioinformatics best-practice analysis pipeline for calculating
polygenic [risk] scores on samples with imputed genotypes using existing scoring 
files from the [Polygenic Score (PGS) Catalog](https://www.pgscatalog.org/) and/or user-defined PGS/PRS.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool
to run tasks across multiple compute infrastructures in a very portable
manner (e.g. at the source of your dataset). It uses Docker/Singularity containers that make 
results highly reproducible by automating software installation. The 
[Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this
pipeline uses one container per process which makes it much easier to maintain
and update software dependencies. Where possible, these processes have been
submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) 
in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

## Pipeline summary

1. Optionally, fetch a scorefile from the PGS Catalog API
2. Validate PGS Catalog and/or user-defined scoring file formays
3. Convert target genotype data (e.g. plink1/2 files, VCF) to plink format automatically
5. Relabel variants to a common identifier
6. Match variants in the scoring file against variants in the genotyping data
7. Calculate scores for each sample (handling multiple scores in paralell)
8. Produce a summary report

### Features in development

- Ancestry estimation using reference datasets
- Multiple scoring file support
- Custom scoring file support
- Multiple genome build support

## Quick Start

1. Install
[`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation)
(`>=21.04.0`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/),
[`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/),
[`Podman`](https://podman.io/),
[`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or
[`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline
reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as
a last resort; see
[docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console
    nextflow run pgscatalog/pgsc_calc -profile test,<docker/singularity/podman/shifter/charliecloud/conda/institute>
    ```

4. Start running your own analysis!

    ```console
    nextflow run pgscatalog/pgsc_calc -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> --input samplesheet.csv --accession PGS001229
    ```

## Documentation

[Full documentation is available on Github
pages](https://pgscatalog.github.io/pgsc_calc/).

## Credits

pgscatalog/pgsc_calc is developed as part of the PGS Catalog project, a
collaboration between the University of Cambridge’s Department of Public Health
and Primary Care (Michael Inouye, Samuel Lambert) and the European
Bioinformatics Institute (Helen Parkinson, Laura Harris).

The pipeline seeks to provide a standardized workflow for PGS calculation and
ancestry inference implemented in nextflow derived from an existing set of
tools/scripts developed by Inouye lab (Rodrigo Canovas, Scott Ritchie, Jingqin
Wu) and PGS Catalog teams (Samuel Lambert, Laurent Gil).

The adaptation of the codebase and nextflow implementation is written by
Benjamin Wingfield with input and supervision from Samuel Lambert (PGS Catalog)
and Aoife McMahon (EBI). Development of new features, testing, and code review
is ongoing including Inouye lab members (Rodrigo Canovas) and others. A
manuscript describing the tool is in preparation. In the meantime if you use the
tool we ask you to cite the repo and the paper describing the PGS Catalog
resource:

- >PGS Catalog Calculator _(in development)_. PGS Catalog Team. [https://github.com/PGScatalog/pgsc_calc](https://github.com/PGScatalog/pgsc_calc)
- >Lambert _et al._ (2021) The Polygenic Score Catalog as an open database for reproducibility and systematic evaluation.
Nature Genetics. 53:420–425 doi:[10.1038/s41588-021-00783-5](https://doi.org/10.1038/s41588-021-00783-5).

This pipeline uses code and infrastructure developed and maintained by the
[nf-core](https://nf-co.re) community, reused here under the [MIT
license](https://github.com/nf-core/tools/blob/master/LICENSE).

> The nf-core framework for community-curated bioinformatics pipelines.
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.

In addition, references of tools and data used in this pipeline are described in
[`CITATIONS.md`](CITATIONS.md).

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.
