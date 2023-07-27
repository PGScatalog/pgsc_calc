.. _norm:

Reporting and adjusting PGS in the context of genetic ancestry
==============================================================

v2 of the ``pgsc_calc`` pipeline introduces the ability to analyse the genetic ancestry of the individuals in your
sampleset in comparison to a reference panel (default: 1000 Genomes) using principal component analysis (PCA). In this
document we explain how the PCA is derived, and how it can be used to report polygenic scores that are adjusted or
contextualized by genetic ancestry using multiple different methods.


Motivation: PGS distributions and genetic ancestry
--------------------------------------------------
PGS are developed to measure an individual’s genetic predisposition to a disease or trait. A common way to express this
is as a relative measure of predisposition (e.g. risk) compared to a reference population (often presented as a Z-score
or percentile). The choice of reference population is important, as the mean and variance of a PGS can differ between
different genetic ancestry groups (`Figure 1`_) as been shown previously. [#Reisberg2017]_ [#Martin2017]_

.. _Figure 1:
.. figure:: screenshots/p_SUM.png
    :width: 450
    :alt: Example PGS distributions stratified by population groups.

    **Figure 1. Example of a PGS with shifted distributions in different ancestry groups.** Shown
    here is the distribution of PGS000018 (metaGRS_CAD) calculated using the SUM method
    in the 1000 Genomes reference panel, stratified by genetic ancestry groups (superpopulation labels).

It is important to note that differences in the means between different ancestry groups do not necessarily correspond
to differences in the risk (e.g., changes in disease prevalence, or mean biomarker values) between the populations.
Instead, these differences are caused by changes in allele frequencies and linkage disequilibrium (LD) patterns between
ancestry groups. This illustrates that the genetic ancestry is important for determining the relative risk, and multiple
methods that can account for these differences have been implemented within the pgsc_calc pipeline.

Methods for reporting and adjusting PGS in the context of ancestry
------------------------------------------------------------------
When a PGS is being applied to a genetically homogenous population (e.g. cluster of individuals of similar genetic
ancestry), then the standard normalization is to normalize the calculated PGS using the sample mean and standard
deviation. This can be performed by running pgsc_calc and taking the Z-score of the PGS SUM. However, wish to adjust
the score to remove the effects of genetic ancestry on score distributions than the ``--run_ancestry`` method can
combine your PGS with a reference panel of individuals (default 1000 Genomes) and adjusted using multiple methods
(`Figure 2`_). These methods both start by creating a PCA of the reference panel, and projecting individual(s) genotypes
into the genetic ancestry space to determine their placement. The two groups of methods (empirical and continuous
PCA-based) use these data and the calculated PGS to report the PGS and we describe them below.

.. _Figure 2:
.. figure:: screenshots/Fig_AncestryMethods.png
    :width: 1500
    :alt: Schematic figure detailing methods for contextualizing or adjusting PGS in the context of genetic ancestry.

    **Figure 2. Schematic figure detailing empirical and PCA-based methods for contextualizing or adjusting PGS
    with genetic ancestry.** Data is for the normalization of PGS000018 (metaGRS_CAD) in 1000 Genomes,
    when applying ``pgsc_calc --run_ancestry`` to data from the Human Genome Diversity Project (HGDP) data.


Empirical methods
~~~~~~~~~~~~~~~~~
A common way to report the relative PGS for an individual is by comparing their score with a distribution
of scores from genetically similar individuals (similar to taking a Z-score within a genetically homogenous population
above). [#ImputeMe] To define the correct reference distribution of PGS for an individual we first train a classifier
to predict the population labels (pre-defined ancestry groups of the reference panel) from the PCA loadings for the
reference. This classifier is then applied to individuals in the target dataset to identify the population they are
most similar to in genetic ancestry space. Then the relative PGS for each individual is calculated by comparing their
score to the reference distribution and reporting it as a percentile (output column: ``percentile_MostSimilarPop``) or by taking a
Z-score (output column: ``Z_MostSimilarPop``).


PCA-based methods
~~~~~~~~~~~~~~~~~
A second way to remove the effect of genetic ancestry on PGS distributions is to treat ancestry as a continuum
(represented by loadings in PCA-space) and use regression to adjust for shifts therein. Using regression has the
benefit of not assigning individuals to specific ancestry groups, which may be particularly problematic for empirical
methods when an individual has an ancestry that isn’t well represented by the reference panel. The original incarnation
of this method was proposed by Khera et al. (2019) [#Khera2019]_ and uses the PCA loadings to adjust for differences in
the means of PGS distributions across ancestries by fitting a regression of PGS values based on PCA-loadings of
individuals of the reference panel. To calculate the normalized PGS the predicted PGS based on the PCA-loadings is
subtracted from the PGS and normalized by the standard deviation in the reference population to achieve PGS
distributions that are centred at 0 for each genetic ancestry group (output column: ``Z_norm1``) with the benefit on not
relying on any population labels during model fitting.

The first method (``Z_norm1``)  has the result of normalizing the first moment of the PGS distribution (mean); however,
the second moment of the PGS distribution (variance) can also differ between ancestry groups. A second regression of
the PCA-loadings on the squared residuals (difference of the PGS and the predicted PGS) can be fit to estimate a
predicted standard deviation based on genetic ancestry, as was proposed by Khan et al. (2022). [#Khan2022]_  The
predicted standard deviation (distance from the mean PGS based on ancestry) is used to normalize the residual PGS and
get a new estimate of relative risk (output column: ``Z_norm2``) where the dispersion of the PGS distribution is more equal
across ancestry groups.


Implementation within ``pgsc_calc``
-----------------------------------


Interpretation of PGS-adjustment data from ``pgsc_calc``
--------------------------------------------------------




.. rubric:: Citations
.. [#Reisberg2017] Reisberg S, et al. (2017) Comparing distributions of polygenic risk scores of type 2 diabetes and coronary heart disease within different populations. PLoS ONE 12(7):e0179238. https://doi.org/10.1371/journal.pone.0179238
.. [#Martin2017] Martin, A.R., et al. (2017) Human Demographic History Impacts Genetic Risk Prediction across Diverse Populations. The American Journal of Human Genetics 100(4):635-649. https://doi.org/10.1016/j.ajhg.2017.03.004
.. [#ImputeMe] Folkersen, L., et al. (2020) Impute.me: An Open-Source, Non-profit Tool for Using Data From Direct-to-Consumer Genetic Testing to Calculate and Interpret Polygenic Risk Scores. Frontiers in Genetics 11:578. https://doi.org/10.3389/fgene.2020.00578
.. [#Khera2019] Khera A.V., et al. (2019) Whole-Genome Sequencing to Characterize Monogenic and Polygenic Contributions in Patients Hospitalized With Early-Onset Myocardial Infarction. Circulation 139:1593–1602. https://doi.org/10.1161/CIRCULATIONAHA.118.035658
.. [#Khan2022] Khan, A., et al. (2022) Genome-wide polygenic score to predict chronic kidney disease across ancestries. Nature Medicine. https://doi.org/10.1038/s41591-022-01869-1