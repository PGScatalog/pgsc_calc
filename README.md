# `pgsc_calc`: PGS Catalog Calculator

:rotating_light: This pipeline is under active development and may break at any time :rotating_light:

:rotating_light: We will tag stable-ish releases ASAP :rotating_light:

[![pgscatalog/pgsc_calc CI](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml/badge.svg)](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml)
[![nf-core linting](https://github.com/PGScatalog/pgsc_calc/actions/workflows/linting.yml/badge.svg)](https://github.com/PGScatalog/pgsc_calc/actions/workflows/linting.yml)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.04.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

## Introduction

`pgsc_calc` is a bioinformatics best-practice analysis pipeline for applying
scoring files from the [Polygenic Score (PGS) Catalog](https://www.pgscatalog.org/) to target genotyped samples.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. Genotype harmonization
2. PGS Catalog Scoring file download + variant matching
3. PGS Cacluation (`plink2 --score`)
4. ...

### Features In Development

- Ancestry estimation using reference datasets.

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.04.0`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console
    nextflow run pgscatalog/pgsc_calc -profile test,<docker/singularity/podman/shifter/charliecloud/conda/institute>
    ```

    > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > - If you are using `singularity` then the pipeline will auto-detect this and attempt to download the Singularity images directly as opposed to performing a conversion from Docker images. If you are persistently observing issues downloading Singularity images directly due to timeout or network issues then please use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, it is highly recommended to use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to pre-download all of the required containers before running the pipeline and to set the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options to be able to store and re-use the images from a central location for future pipeline runs.
    > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

    ```console
    nextflow run pgscatalog/pgsc_calc -profile
    <docker/singularity/podman/shifter/charliecloud/conda/institute> --input
    samplesheet.csv --accession PGS001229
    ```

## Documentation

IN PROGRESS: The pgscatalog/pgsc_calc pipeline will be distributed with documentation about the pipeline
usage, parameters, and outputs.

## Credits

`pgscatalog/pgsc_calc` is developed as part of the [PGS Catalog](https://www.pgscatalog.org/about) project, a collaboration
between the University of Cambridge’s Department of Public Health and Primary Care (Michael Inouye, Samuel Lambert) and
the European Bioinformatics Institute (Helen Parkinson, Laura Harris). The pipeline seeks to provide a standardized
workflow for PGS calculation and ancestry inference implemented in netxflow derived from an existing set of tools/scripts
developed by Inouye lab (Rodrigo Canovas, Scott Ritchie, Jingqin Wu) and PGS Catalog teams (Samuel Lambert, Laurent Gil).
The adaptation of the codebase and nextflow implementation is written by Benjamin Wingfield with input and supervision
from Samuel Lambert (PGS Catalog) and Aoife McMahon (EBI). Development of new features, testing, and code review is
ongoing including Inouye lab members (Rodrigo Canovas) and others. A manuscript describing the tool is _in preparation_, in
the meantime if you use the tool we ask you to cite the repo and the paper describing the PGS Catalog resource:

- >PGS Catalog Calculator _(in development)_. PGS Catalog Team. [https://github.com/PGScatalog/pgsc_calc](https://github.com/PGScatalog/pgsc_calc)
- >Lambert _et al._ (2021) The Polygenic Score Catalog as an open database for reproducibility and systematic evaluation.
Nature Genetics. 53:420–425 doi:[10.1038/s41588-021-00783-5](https://doi.org/10.1038/s41588-021-00783-5).

NOTE: the pipeline is distributed and makes use of datasets (e.g. 1000 Genomes and CINECA synthetic data) that
are provided under specific data licenses (see the [assets](assets/README.md) directory README for more information). It is up to
end-users to ensure that their use conforms to these restrictions.

<!-- TODO nf-core: If applicable, make list of people who have also contributed
-->

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> The nf-core framework for community-curated bioinformatics pipelines.
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.

In addition, references of tools and data used in this pipeline are described in [`CITATIONS.md`](CITATIONS.md).

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.
