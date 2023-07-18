:orphan:
   
``pgsc_calc``: a reproducible workflow to calculate polygenic scores
====================================================================

The ``pgsc_calc`` workflow makes it easy to calculate a :term:`polygenic score`
(PGS) using scoring files published in the `Polygenic Score (PGS) Catalog`_
|:dna:| and/or custom scoring files.

The calculator workflow automates PGS downloads from the Catalog, variant
matching between scoring files and target genotyping samplesets, and the
parallel calculation of multiple PGS. Genetic ancestry assignment and PGS
normalisation methods are also supported.

.. _`Polygenic Score (PGS) Catalog`: https://www.pgscatalog.org/

Workflow summary
----------------

.. image:: https://user-images.githubusercontent.com/11425618/195053396-a3eaf31c-b3d5-44ff-a36c-4ef6d7958668.png
    :width: 600
    :alt: `pgsc_calc` workflow diagram

|

The workflow does the following steps:

- Downloading scoring files using the PGS Catalog API in a specified genome build (GRCh37 and GRCh38).
- Reading custom scoring files (and performing a liftover if genotyping data is in a different build).
- Automatically combines and creates scoring files for efficient parallel
  computation of multiple PGS
- Matching variants in the scoring files against variants in the target dataset (in plink bfile/pfile or VCF format)
- Calculates PGS for all samples (linear sum of weights and dosages)
- Creates a summary report to visualize score distributions and pipeline metadata (variant matching QC)

And optionally:

- Using reference genomes to automatically assign the genetic ancestry of target
  genomes
- Normalising calculated PGS to account for genetic ancestry

.. tip:: To enable these optional steps, see :ref:`ancestry`
         
The workflow relies on open source scientific software, including:

- `PLINK 2`_
- `PGS Catalog Utilities`_
- `FRAPOSA`_

A full description of included software is described in :ref:`containers`.

.. _PLINK 2: https://www.cog-genomics.org/plink/2.0/
.. _PGS Catalog Utilities: https://github.com/PGScatalog/pgscatalog_utils
.. _FRAPOSA: https://github.com/PGScatalog/fraposa_pgsc

Quick example
-------------

1. Install :doc:`Nextflow<getting-started>`
2. Install `Docker`_ or `Singularity`_ (minimum ``v3.8.3``) for full
   reproducibility or `Conda`_ as a fallback
3. Calculate some polygenic scores using synthetic test data:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile test,docker

The workflow should output:

.. code-block:: console

    ... <configuration messages intentionally not shown> ...
    ------------------------------------------------------
    If you use pgscatalog/pgsc_calc for your analysis please cite:

    * The Polygenic Score Catalog
      https://doi.org/10.1038/s41588-021-00783-5

    * The nf-core framework
      https://doi.org/10.1038/s41587-020-0439-x

    * Software dependencies
      https://github.com/pgscatalog/pgsc_calc/blob/master/CITATIONS.md
    ------------------------------------------------------
    executor >  local (7)

    [49/d28766] process > PGSC_CALC:PGSCALC:INPUT_CHECK:SAMPLESHEET_JSON (samplesheet.csv)           [100%] 1 of 1 ✔
    [c3/a8e0d9] process > PGSC_CALC:PGSCALC:INPUT_CHECK:SCOREFILE_CHECK                              [100%] 1 of 1 ✔
    [-        ] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:PLINK2_VCF                               -
    [7c/5cca6c] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:PLINK2_BFILE (cineca_synthetic_subset)   [100%] 1 of 1 ✔
    [3b/ce0e39] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:MATCH_VARIANTS (cineca_synthetic_subset) [100%] 1 of 1 ✔
    [2e/fb3233] process > PGSC_CALC:PGSCALC:APPLY_SCORE:PLINK2_SCORE (cineca_synthetic_subset)       [100%] 1 of 1 ✔
    [b5/fc5b1e] process > PGSC_CALC:PGSCALC:APPLY_SCORE:SCORE_REPORT (1)                             [100%] 1 of 1 ✔
    [03/009cb6] process > PGSC_CALC:PGSCALC:DUMPSOFTWAREVERSIONS (1)                                 [100%] 1 of 1 ✔
    -[pgscatalog/pgsc_calc] Pipeline completed successfully-
                
.. note:: The ``docker`` profile option can be replaced with ``singularity`` or
          ``conda`` depending on your local environment

.. _`Docker`: https://docs.docker.com/get-docker/
.. _`Singularity`: https://sylabs.io/
.. _`Conda`: https://conda.io

If you want to try the workflow with your own data, have a look at the
:ref:`get started` section.

Documentation
-------------

- :doc:`Get started<getting-started>`: install pgsc_calc and calculate some polygenic scores quickly
- :doc:`How-to guides<how-to/index>`: step-by-step guides, covering different use cases
- :doc:`Reference guides<reference/index>`: technical information about workflow configuration
- :doc:`Explanations<explanation/index>`: more detailed explanations about PGS calculation

Changelog
---------

The :doc:`Changelog page<changelog>` describes fixes and enhancements for each version.


Credits
-------

``pgscatalog/pgsc_calc`` is developed as part of the PGS Catalog project, a
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
manuscript describing the tool is in preparation (see `Citations <Citations_>`_) and we
welcome ongoing community feedback before then.

Citations
~~~~~~~~~

If you use ``pgscatalog/pgsc_calc`` in your analysis, please cite:

    PGS Catalog Calculator (in development) [0]_. PGS Catalog
    Team. https://github.com/PGScatalog/pgsc_calc

    Lambert `et al.` (2021) The Polygenic Score Catalog as an open database for
    reproducibility and systematic evaluation.  Nature Genetics. 53:420–425
    doi:`10.1038/s41588-021-00783-5`_.

In addition, please remember to cite the primary publications for any PGS Catalog scores
you use in your analyses, and the underlying data/software tools described in the `citations file`_.

.. _citations file: https://github.com/PGScatalog/pgsc_calc/blob/master/CITATIONS.md
.. _10.1038/s41588-021-00783-5: https://doi.org/10.1038/s41588-021-00783-5
.. [0] A manuscript is in development but the calculated scores have been
       validated against UK Biobank since v1.1.0


License Information
~~~~~~~~~~~~~~~~~~~

This pipeline is distributed  under an `Apache 2.0 license`_, but makes use of
multiple open-source software and datasets (complete list in the `citations file`_)
that are distributed under their own licenses. Notably:

- `Nextflow (Apache 2.0 license)`_ and `nf-core`_ (`MIT license`_). See & cite
  `Ewels et al. Nature Biotech (2020)`_ for additional information about the project.
- PLINK 1/2 software (`GPLv3+`_)
- `CINECA synthetic cohort <https://doi.org/10.5281/zenodo.5082689>`_ data for test dataset (`CC-BY-NC-SA <https://creativecommons.org/licenses/by-nc-sa/4.0/>`_)

We note that it is up to end-users to ensure that their use of the pipeline
and test data conforms to the license restrictions.

.. _GPLv3+: https://www.cog-genomics.org/plink/2.0/dev
.. _Nextflow (Apache 2.0 license): https://github.com/nextflow-io/nextflow/blob/master/COPYING
.. _MIT license: https://github.com/nf-core/tools/blob/master/LICENSE
.. _nf-core: https://nf-co.re
.. _Apache 2.0 license: https://github.com/PGScatalog/pgsc_calc/blob/master/LICENSE
.. _Ewels et al. Nature Biotech (2020): https://doi.org/10.1038/s41587-020-0439-x

Funding
~~~~~~~

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.
