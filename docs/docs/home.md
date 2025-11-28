---
sidebar_label: "Home"
sidebar_position: 1
slug: /
---

# ``pgsc_calc``: a reproducible workflow to calculate polygenic scores


The ``pgsc_calc`` workflow makes it easy to calculate a polygenic score
(PGS) using scoring files published in the [Polygenic Score (PGS) Catalog :dna:](https://pgscatalog.org) or custom scoring files.

The calculator workflow automates PGS downloads from the Catalog, variant
matching between scoring files and target genotyping samplesets, and the
parallel calculation of multiple PGS. It supports VCF and BGEN input.

:::info

* You are browsing the documentation for ``pgsc_calc`` v3 release candidate 1
* This is **pre-release** software designed to be more flexible and scale better than v2
* More release candidates are planned in the near future, **things may break in unexpected ways** compared to v2
* Many v2 features are missing from this release candidate (e.g. ancestry normalisation)

:::


## Workflow summary

The workflow performs the following steps:

- Downloading scoring files using the PGS Catalog API in a specified genome build (GRCh37 and GRCh38).
- Reading custom scoring files (and performing a liftover if genotyping data is in a different build).
- Automatically combines and creates scoring files for efficient parallel
  computation of multiple PGS.
- Matches variants in the scoring files against variants in the target dataset (indexed VCF/BGEN)
- Calculates PGS for all samples (linear sum of weights and dosages).
- Creates a summary report to visualize score distributions and pipeline metadata (variant matching QC).

## Quick example

1. Install [Nextflow](https://nextflow.io)
2. Install [Docker](https://www.docker.com/get-started/) or [Singularity](https://docs.sylabs.io/guides/latest/user-guide/)/[Apptainer](https://apptainer.org/) for full reproducibility, or [conda](https://docs.conda.io/projects/conda/en/stable/user-guide/install/index.html) as a fallback
3. Calculate some polygenic scores using test data:

```bash
$ nextflow run pgscatalog/pgsc_calc -r v3-rc1 -profile test,<docker/singularity/conda>
```

The workflow should output something like:

```bash
...
If you use pgscatalog/pgsc_calc for your analysis please cite:

* The Polygenic Score (PGS) Catalog
    https://doi.org/10.1038/s41588-024-01937-x
    https://doi.org/10.1038/s41588-021-00783-5

* The nf-core framework
    https://doi.org/10.1038/s41587-020-0439-x

* Software dependencies
    https://github.com/pgscatalog/pgsc_calc/blob/main/CITATIONS.md

The test profile is used to install the workflow and verify the software is working correctly on your system.
Test input data and results are are only useful as examples of outputs, and are not biologically meaningful.
[92/ee02db] Submitted process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_FORMAT ([PGS000586_hmPOS_GRCh38.txt.gz])
[fb/c51bac] Submitted process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_LOAD ([sampleset:1000G, chrom:[], file_format:bgen, genotyping_method:array])
[39/5c9528] Submitted process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_SCORE (1)
- [pgscatalog/pgsc_calc] Pipeline completed successfully -
```

The `docker` profile option can be replaced with `singularity/apptainer` or `conda` depending on your local environment


If you want to try the workflow with your own data, have a look at [getting started](getting-started.md).


## Changelog

The [changelog page](https://github.com/pgscatalog/pgsc_calc/releases) describes fixes and enhancements for each version.

## Credits


`pgscatalog/pgsc_calc` is developed as part of the PGS Catalog project, a
collaboration between the University of Cambridge’s Department of Public Health
and Primary Care (Michael Inouye, Samuel Lambert) and the European
Bioinformatics Institute (Helen Parkinson, Laura Harris).

The pipeline seeks to provide a standardized workflow for PGS calculation and
ancestry inference implemented in nextflow derived from an existing set of
tools/scripts developed by Inouye lab (Rodrigo Canovas, Scott Ritchie, Jingqin
Wu) and PGS Catalog teams (Samuel Lambert, Laurent Gil).

The adaptation of the codebase, nextflow implementation, and PGS
Catalog features are written by Benjamin Wingfield, Samuel Lambert,
Laurent Gil with additional input from Aoife McMahon
(EBI). Development of new features, testing, and code review is
ongoing including Inouye lab members (Rodrigo Canovas, Scott Ritchie)
and others. We welcome ongoing community feedback via our [discussion
board](https://github.com/PGScatalog/pgsc_calc/discussions/) or [issue
tracker](https://github.com/PGScatalog/pgsc_calc/issues).

## Citations

If you use `pgscatalog/pgsc_calc` in your analysis, please cite:

> Lambert, Wingfield, _et al._ (2024) Enhancing the Polygenic Score Catalog with tools for score calculation and ancestry normalization. Nature Genetics. [doi:10.1038/s41588-024-01937-x](https://doi.org/10.1038/s41588-024-01937-x)

In addition, please remember to cite the primary publications for any
PGS Catalog scores you use in your analyses, and the underlying
data/software tools described in the [citations
file](https://github.com/pgscatalog/pgsc_calc/blob/main/CITATIONS.md).


## License


This pipeline is distributed under an [Apache 2.0
license](https://github.com/PGScatalog/pgsc_calc/blob/main/LICENSE),
but makes use of multiple open-source software and datasets (complete
list in the [citations
file](https://github.com/pgscatalog/pgsc_calc/blob/main/CITATIONS.md))
that are distributed under their own licenses. Notably:

- Nextflow (Apache 2.0) and nf-core (MIT). See & cite [Ewels et al. Nature Biotech (2020)](https://doi.org/10.1038/s41587-020-0439-x) for additional information about the project.
- The `pgscatalog.utils` Python package (Apache 2.0)
- A subset of the 1000 Genomes publicly available dataset is used for testing data

Scoring files in the PGS Catalog are generally licensed under the
permissive EMBL-EBI [terms of
use](https://www.ebi.ac.uk/about/terms-of-use/). Some scores have
specific license conditions (e.g. non-commercial), which are described
in the PGS Catalog if applicable.

We note that it is up to end-users to ensure that their use of the
pipeline and test data conforms to the license restrictions.

## Funding

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.