.. _norm:

Reporting and adjusting PGS in the context of genetic ancestry
==============================================================

v2 of the ``pgsc_calc`` pipeline introduces the ability to analyse the genetic ancestry
of the individuals in your sampleset in comparison to a reference panel (default:
1000 Genomes) using principal component analysis (PCA). In this document we explain how the
PCA is derived, and how it can be used to report polygenic scores that are adjusted or
contextualized by genetic ancestry using multiple different methods.


Motivation: PGS distributions and genetic ancestry
--------------------------------------------------
PGS are developed to measure an individual’s genetic predisposition to a disease or trait.
A common way to express this is as a relative measure of predisposition (e.g. risk) compared to
a reference population (often presented as a Z-score or percentile). The choice of reference
population is important, as the mean and variance of a PGS can differ between different genetic
ancestry groups (Figure 1).

.. figure:: screenshots/p_SUM.png
    :width: 250
    :alt: Example PGS distributions stratified by population groups.

    **Figure 1. Example of a PGS with shifted distributions in different ancestry groups.** Shown
    here is the distribution of PGS000018 (metaGRS_CAD) calculated using the SUM method
    in the 1000 Genomes reference panel, stratified by genetic ancestry groups (superpopulation labels).

It is important to note that differences in the means between different ancestry groups do not
necessarily correspond to differences in the risk (e.g., changes in disease prevalence, or mean
biomarker values) between the populations. Instead, these differences are caused by changes in
allele frequencies and linkage disequilibrium (LD) patterns between ancestry groups. This illustrates
that the genetic ancestry is important for determining the relative risk, and multiple methods that can
account for these differences have been implemented within the pgsc_calc pipeline.

Methods for reporting and adjusting PGS in the context of ancestry
------------------------------------------------------------------
If the PGS is being calculated on a genetically homogenous population (e.g. cluster of individuals of similar genetic
ancestry), then the standard normalization is to normalize the PGS using the sample mean and standard deviation.
However, if you are calculating a PGS for individual(s) and do not already have a reference population then they can be
compared to a reference panel of individuals using multiple methods (Figure 2).

.. figure:: screenshots/Fig_AncestryMethods.png
    :width: 1000
    :alt: Schematic figure detailing methods for contextualizing or adjusting PGS in the context of genetic ancestry.

    **Figure 2. Schematic figure detailing empirical and PCA-based methods for contextualizing or
    adjusting PGS with genetic ancestry.** Data is for the normalization of PGS000018 (metaGRS_CAD) in 1000 Genomes,
    when applying ``pgsc_calc`` to data from the Human Genome Diversity Project (HGDP) data.


Implementation within ``pgsc_calc``
-----------------------------------


Interpretation of PGS-adjustment data from ``pgsc_calc``
--------------------------------------------------------

