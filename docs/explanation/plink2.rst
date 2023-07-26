.. _plink2:

Why not just use ``plink2 --score``?
====================================

You might be curious what ``pgsc_calc`` does that ``plink2 --score`` doesn't. We
use ``plink2`` internally to calculate all scores but offer some extra features:

- We match the variants from scoring files (often from different genome builds) against
  the target genome using multiple strategies, taking into account the strand alignment,
  ambiguous or multi-allelic matches, duplicated variants/matches, and overlaps between
  datasets (e.g. with a reference for ancestry).

- One important output is an auditable log that covers the union of all variants
  across the scoring files, tracking how the variants matched the target genomes and
  provide reasons why they are excluded from contributing to the final calculated scores
  based on user-specified settings and thresholds for variant matching.

- From the matched variants the workflow outputs a new set of scoring files
  which are used by plink2 for scoring. The new scoring files combine multiple PGS in
  a single file to calculate scores in parallel. These scoring files are automatically
  split by effect type and across duplicate variant IDs with different effect alleles,
  then the split scores are aggregated.

- The pipeline also calculates genetic ancestry using a reference panel (default 1000 Genomes)
  handling the data handling, variant matching, derivation of the PCA space, and projection of
  target samples into the PCA space using robust methods (implemented in fraposa_pgsc_).

- Scores can be adjusted using genetic ancestry data using multiple methods (see :ref:`norm`).

.. _fraposa_pgsc: https://github.com/PGScatalog/fraposa_pgsc

Summary
-------

- For a seasoned bioinformatician the workflow offers convenient integration with the PGS Catalog
  and simplifies large scale PGS calculation on HPCs.

- Genetic ancestry similarity calculations and adjustment of PGS using established methods
  using reproducible code and datasets.

- For a data scientist or somebody less familiar with the intricacies of PGS
  calculation, ``pgsc_calc`` automates many of the complex steps and analysis choices needed to
  calculate PGS using multiple software tools.

