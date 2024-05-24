# The Polygenic Score Catalog Calculator (`pgsc_calc`)

[![Documentation Status](https://readthedocs.org/projects/pgsc-calc/badge/?version=latest)](https://pgsc-calc.readthedocs.io/en/latest/?badge=latest)
[![pgscatalog/pgsc_calc CI](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml/badge.svg)](https://github.com/PGScatalog/pgsc_calc/actions/workflows/ci.yml)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.5970794.svg)](https://doi.org/10.5281/zenodo.5970794)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-≥23.10.0-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)

## Introduction

`pgsc_calc` is a bioinformatics best-practice analysis pipeline for calculating
polygenic [risk] scores on samples with imputed genotypes using existing scoring
files from the [Polygenic Score (PGS) Catalog](https://www.pgscatalog.org/)
and/or user-defined PGS/PRS.

## Pipeline summary

<p align="center">
  <img width="80%" src="https://github.com/PGScatalog/pgsc_calc/assets/11425618/f766b28c-0f75-4344-abf3-3463946e36cc">
</p>

The workflow performs the following steps:

* Downloading scoring files using the PGS Catalog API in a specified genome build (GRCh37 and GRCh38).
* Reading custom scoring files (and performing a liftover if genotyping data is in a different build).
* Automatically combines and creates scoring files for efficient parallel computation of multiple PGS
    - Matching variants in the scoring files against variants in the target dataset (in plink bfile/pfile or VCF format)
* Calculates PGS for all samples (linear sum of weights and dosages)
* Creates a summary report to visualize score distributions and pipeline metadata (variant matching QC)

And optionally:

- Genetic Ancestry: calculate similarity of target samples to populations in a
  reference dataset ([1000 Genomes (1000G)](http://www.nature.com/nature/journal/v526/n7571/full/nature15393.html)), using principal components analysis (PCA)
- PGS Normalization: Using reference population data and/or PCA projections to report
  individual-level PGS predictions (e.g. percentiles, z-scores) that account for genetic ancestry

See documentation for a list of planned [features under development](https://pgsc-calc.readthedocs.io/en/latest/index.html#Features-under-development).

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
is ongoing including Inouye lab members (Rodrigo Canovas, Scott Ritchie) and others. A
manuscript describing the tool is *in preparation*. In the meantime if you use the
tool we ask you to cite the repo and the paper describing the PGS Catalog
resource:

- >PGS Catalog Calculator _(in preparation)_. PGS Catalog
  Team. [https://github.com/PGScatalog/pgsc_calc](https://github.com/PGScatalog/pgsc_calc)
- >Lambert _et al._ (2021) The Polygenic Score Catalog as an open database for
reproducibility and systematic evaluation.  Nature Genetics. 53:420–425
doi:[10.1038/s41588-021-00783-5](https://doi.org/10.1038/s41588-021-00783-5).

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
