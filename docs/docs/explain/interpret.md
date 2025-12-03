---
sidebar_label: Interpreting polygenic scores
description: You've calculated some polygenic scores, now what?
sidebar_position: 2
---

# Interpreting polygenic scores


## Overview

The PGS Catalog Calculator (`pgsc_calc`) produces standardised outputs and reports that make polygenic score (PGS) analyses transparent, reproducible, and interpretable.

While [the report explanation describes file structures and field definitions](report.md), this page explains how to read, interpret, and communicate those results responsibly.

:::tip

Currently ancestry normalisation is only available in `pgsc_calc` v2

:::

## 1. Interpreting PGS Values

A polygenic score represents a relative estimate of genetic predisposition, derived by summing the effects of many genetic variants weighted by their estimated effect sizes.

The SUM (or normalised) value in `pgsc_calc` output reflects an individual’s relative genetic tendency within the dataset analysed, with some important caveats:

* Higher scores indicate greater genetic predisposition relative to others in the same cohort - if basic mode is run on a genetically homogenous population, or if ancestry adjustment is performed on a diverse population.
* The distribution of PGS scores can differ between different genetic ancestry groups, but this does not necessarily correspond to differences in the risk (e.g., changes in disease prevalence, or mean biomarker values) between the populations. Instead, these differences are caused by changes in allele frequencies and linkage disequilibrium (LD) patterns between ancestry groups. [We recommend using the ancestry normalisation feature to address this confounding](https://pgsc-calc.readthedocs.io/en/latest/explanation/geneticancestry.html).
* PGS values are not absolute measures of risk or causation. Even after adjusting PGS distributions for genetic ancestry, the effect size of the PGS might still be different in each ancestry distribution.
* Predictive accuracy depends strongly on how similar the target population is to the discovery cohort.

:::info Interpretation

* Treat PGS as statistical predictors, not diagnostic tests.
* Individuals with high scores may never develop the phenotype, and individuals with low scores sometimes will.
* Interpretation should always consider population context, phenotype definition, and validation performance.

See [Abu-El-Hija _et al._](#7-further-reading) for more details.

:::

## 2. Variant Matching and Quality Control

Variant matching underpins reliable score calculation.

The match outputs and matching tables in the HTML report show how many variants in each PGS scoring file were successfully aligned with the target genotypes.

Key indicators include:

* High match rate (>95%) indicates good compatibility.
* A high proportion of excluded or flipped variants can signal build or reference mismatches.
* Scores that require reducing the `--min_overlap` threshold to calculate should be reviewed carefully.

:::info Interpretation

Variant matching statistics are direct indicators of dissimilarity from the original PGS and uncertainty.
A poorly matched score may not reproduce published performance (e.g. explain less variation in the trait) and can yield biased results.
Always check the variant overlap summaries in `report.html` before using scores in downstream analyses.

:::

## 3. Understanding the Report

Each `pgsc_calc` run produces a summary HTML report (`report.html` file) containing:

* Metadata for the PGS files applied.
* Variant matching and overlap statistics.
* Ancestry projections (PCA plots).
* PGS distributions (density plots).

These components give a quick overview of data quality and interpretability.

:::info Interpretation

Use these plots and tables to identify potential issues:

* Narrow or truncated score distributions may indicate low variant overlap.
* Outliers in PCA plots may represent misclassified or poor-quality samples.
* Large shifts in ancestry-adjusted distributions may reflect population stratification.
* The report is designed to be reviewed before further analysis or publication to ensure scores have been applied appropriately.

:::

## 4. Ancestry and Normalisation

When run with the `--run_ancestry` option, `pgsc_calc` produces additional ancestry-aware outputs (`Z_MostSimilarPop`, `Z_norm1`, `Z_norm2`).
These provide normalised scores that can be compared across ancestry groups, improving equity and interpretability.


:::info Interpretation

Ancestry normalisation helps make scores more comparable across populations, but it introduces its own uncertainties. The “Most Similar Population” label is based on statistical similarity in genetic space, it is not a definitive ancestry classification.
Z-scores and percentiles should always be interpreted relative to the specific reference data used.
Read the full documentation to understand what transformations are being performed on the data https://pgsc-calc.readthedocs.io/en/latest/explanation/geneticancestry.html.

:::

## 5. Communicating Uncertainty

Polygenic scores are probabilistic estimates, not deterministic outcomes.

Uncertainty arises from multiple sources, including:
* Statistical error in GWAS effect estimates or unadjusted confounders (e.g. heritable environmental and lifestyle factors, indirect effects)
* Differences between discovery and target populations.
* Technical artefacts in variant matching or imputation.

:::info Interpretation

Communicate PGS results as relative and probabilistic, never as fixed measures of risk.

Always include:
* The PGS Catalog ID(s) or discovery GWAS details if the score is not in the PGS Catalog.
Target population characteristics (ancestry, sample size).
* `pgsc_calc` version and parameter settings.
* Performance metrics (for example R² or AUC) when available.
* Where possible, visualise results as distributions or deciles rather than single-point estimates.
Explicitly acknowledging uncertainty strengthens reproducibility and responsible communication.

:::

## 6. Best Practices

* Review variant matching and overlap thresholds before interpreting results.
* Use ancestry-normalised or Z-score outputs when comparing applying PGS to individuals of  diverse ancestries.
* Interpret scores within the population context; avoid making absolute statements about risk.
* When using population descriptors use language that describes the similarity of samples to the genetic ancestry label of reference groups, e.g. 1KG-EUR-like (See Box 5-3, [NASEM, 2023](#7-further-reading))
* Report full metadata, target ancestry, and `pgsc_calc` version, in any downstream use.
* Treat uncertainty as an inherent and informative feature of PGS interpretation, not as an error term to be ignored.


## 7. Further Reading

* Abu-El-Haija _et al._ (2023) The clinical application of polygenic risk scores: A points to consider statement of the American College of Medical Genetics and Genomics (ACMG). Genet Med. doi: https://doi.org/10.1016/j.gim.2023.100803

* Lambert, S.A. _et al._ (2024) Enhancing the Polygenic Score Catalog with tools for score calculation and ancestry normalization. https://doi.org/10.1038/s41588-024-01937-x

* Lennon, _et al._ (2024) Selection, optimization and validation of ten chronic disease polygenic risk scores for clinical implementation in diverse US populations. Nat Med https://doi.org/10.1038/s41591-024-02796-z

* Linder (2023) Returning integrated genomic risk and clinical recommendations: The eMERGE study. Genet Med, doi: https://doi.org/10.1016/j.gim.2023.100006

* Lewis & Vassos (2020) Polygenic risk scores: from research tools to clinical instruments.Genome Med, https://doi.org/10.1186/s13073-020-00742-5

* NASEM (National Academies of Sciences, Engineering, and Medicine). (2023) Using Population Descriptors in Genetics and Genomics Research: A New Framework for an Evolving Field. Washington, DC: The National Academies Press.  https://doi.org/10.17226/26902

* Wand _et al._ (2021)  Improving reporting standards for polygenic scores in risk prediction studies. Nature. https://doi.org/10.1038/s41586-021-03243-6
