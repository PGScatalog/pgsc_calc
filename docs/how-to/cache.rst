.. _cache:

How do I speed up `pgsc_calc` computation times and avoid re-running code?
==========================================================================

If you intend to run `pgsc_calc` multiple times on the same target samples (e.g.
on different sets of PGS, with different variant matching flags) it is worth cacheing
information on invariant steps of the pipeline:

- Genotype harmonzation (variant relabeling steps)
- Steps of `--run_ancestry` that: match variants between the target and reference panel and
  generate PCA loadings that can be used to adjust the PGS for ancestry.

To do this you must specify a directory that can store these information across runs using the
`--genotypes_cache` flag to the nextflow command (also see :ref:`param ref`). Future runs of the
pipeline that use the same cache directory should then skip these steps and proceed to run only the
steps needed to calculate new PGS. This is slightly different than using the `-resume command in
nextflow <https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html>`_ which mainly checks the
`work` directory and is more often used for restarting the pipeline when a specific step has failed
(e.g. for exceeding memory limits).

