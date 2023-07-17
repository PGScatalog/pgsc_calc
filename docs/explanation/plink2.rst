.. _plink2:

Why not just use ``plink2 --score``?
====================================

You might be curious what ``pgsc_calc`` does that ``plink2 --score`` doesn't. We
use ``plink2`` internally to calculate all scores but offer some extra features:

- We match the variants from scoring files against the target genome using
  multiple strategies, trying to take into account stuff like strand alignment,
  ambiguous matches, different genome builds, etc.

- One important output is an auditable log that covers the union of all variants
  across the scoring files, tracking how the variants matched and if they were
  excluded from contributing to the final scores and why they might have been
  excluded.

- From the best match candidates the workflow outputs a new set of scoring files
  which are used by plink2. The new scoring files combine multiple scoring files
  to calculate scores in parallel. These scoring files are automatically split
  by effect type and across duplicate variant IDs with different effect alleles,
  then the split scores are aggregated.

- We also take care of calculating genetic ancestry similarity to a reference
  panel using robust PCA methods

- Scores can be optionally normalised across different ancestry groups with a
  range of methods

Summary
-------

- For a seasoned human genetics bioinformatician the workflow mostly
  offers convenient integration with the PGS Catalog and simplifies large scale
  analysis on HPCs.

- Genetic ancestry similarity calculations and automatic ancestry normalisation
  may also be helpful

- For a data scientist or somebody less familiar with the intricacies of PGS
  calculation, ``pgsc_calc`` will be more useful

