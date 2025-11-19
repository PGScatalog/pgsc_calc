# pgscatalog/pgsc_calc

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://github.com/codespaces/new/pgscatalog/pgsc_calc)
[![GitHub Actions CI Status](https://github.com/pgscatalog/pgsc_calc/actions/workflows/nf-test.yml/badge.svg)](https://github.com/pgscatalog/pgsc_calc/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/pgscatalog/pgsc_calc/actions/workflows/linting.yml/badge.svg)](https://github.com/pgscatalog/pgsc_calc/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
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


## v3 release candidate 1 notes

* `pgsc_calc` has always used plink2 ❤️ to calculate polygenic scores
* We have developed a Python package [`pgscatalog.calc`](https://github.com/PGScatalog/pygscatalog/) to replace plink2 in `pgsc_calc`
* This will make it simpler to support new ways of calculating PGS, like WGS data
* `v3-rc1` only implements basic PGS calculation on autosomes for VCF and BGEN files
* We plan to publish release candidates which add support for plink1/2 data, WGS data, and ancestry normalisation 
* **Release candidates are pre-release software that may break unexpectedly in the future**

## Pipeline summary 

The workflow performs the following steps:

* Downloading scoring files using the PGS Catalog API in a specified genome build (GRCh37 and GRCh38).
* Reading custom scoring files (and performing a liftover if genotyping data is in a different build).
* Automatically combines and creates scoring files for efficient parallel computation of multiple PGS
    - Matching variants in the scoring files against variants in the target dataset (in VCF/BGEN formats)
* Calculates PGS for all samples (linear sum of weights and dosages)

### PGS applications and libraries

`pgsc_calc` uses applications and libraries internally developed at the PGS Catalog, which can do helpful things like:

* Query the PGS Catalog to bulk download scoring files in a specific genome build
* Match variants from scoring files to target variants
* Adjust calculated PGS in the context of genetic ancestry

If you want to write Python code to work with PGS, [check out the `pygscatalog` repository to learn more](https://github.com/PGScatalog/pygscatalog).

If you want a simpler way of working with PGS, ignore this section and continue below to learn more about `pgsc_calc`.

## Quick start

1. Install
[`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation)
(`>=23.10.0`)

2. Install [`Docker`](https://docs.docker.com/engine/installation/) or
[`Singularity (v3.8.3 minimum)`](https://www.sylabs.io/guides/3.0/user-guide/)
(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort)

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console
    nextflow run pgscatalog/pgsc_calc -profile test,<docker/singularity/conda>
    ```

4. Start running your own analysis!

    ```console
    nextflow run pgscatalog/pgsc_calc -profile <docker/singularity/conda> --input samplesheet.csv --pgs_id PGS001229
    ```

See [getting
started](https://pgsc-calc.readthedocs.io/en/latest/getting-started.html) for more
details.

## Documentation

[Full documentation is available on Read the Docs](https://pgsc-calc.readthedocs.io/)

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
