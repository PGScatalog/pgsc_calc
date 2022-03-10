:orphan:
   
``pgsc_calc``: Simple polygenic score calculation
=================================================

The ``pgsc_calc`` workflow makes it easy to calculate polygenic scores using
scoring files published in the `Polygenic Score (PGS) Catalog`_ |:dna:|
|:partying_face:| If you have custom scoring files not in the catalog, that's OK
too!

.. _`Polygenic Score (PGS) Catalog`: https://www.pgscatalog.org/

Quick example
-------------

1. Install :doc:`Nextflow<getting-started>`
2. Install `Docker`_ or `Singularity`_ for full reproducibility or `Conda`_ as a
   fallback
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
    [b5/fc5b1e] process > PGSC_CALC:PGSCALC:APPLY_SCORE:MAKE_REPORT (1)                              [100%] 1 of 1 ✔
    [03/009cb6] process > PGSC_CALC:PGSCALC:DUMPSOFTWAREVERSIONS (1)                                 [100%] 1 of 1 ✔
    -[pgscatalog/pgsc_calc] Pipeline completed successfully-
                
.. note:: The ``docker`` profile option can be replaced with ``singularity`` or
          ``conda`` depending on your local environment

.. _`Docker`: https://docs.docker.com/get-docker/
.. _`Singularity`: https://sylabs.io/
.. _`Conda`: https://conda.io

If you want to try the workflow with your own data, have a look at the
:ref:`get started` section.
     
Workflow summary
----------------

- Fetch scoring files using the PGS Catalog API
- Read custom scoring files
- Lift over scoring files to match input genetic data build
- Match variants in the scoring files against variants in the target genome
- Automatically combine and split different scoring files for efficient parallel
  computation of scores  
- Calculate and aggregate split scores
- Publish a summary report

In the future, the calculator will include:

- Ancestry estimation

Documentation
-------------

- :doc:`Get started<getting-started>`: install pgsc_calc and calculate some polygenic scores quickly!
- :doc:`How-to guides<how-to/index>`: step-by-step guides, covering different use cases
- :doc:`Reference guides<reference/index>`: technical information about workflow configuration
- :doc:`Explanation<explanation/index>`: background, discussion of important topics, answers to high level
  questions

Changelog
---------

The :doc:`Changelog page<changelog>` describes fixes and enhancements for each version.

Citations
---------

If you use ``pgscatalog/pgsc_calc`` in your analysis, please cite:

    PGS Catalog Calculator `(in development)`. PGS Catalog
    Team. https://github.com/PGScatalog/pgsc_calc

    Lambert `et al.` (2021) The Polygenic Score Catalog as an open database for
    reproducibility and systematic evaluation.  Nature Genetics. 53:420–425
    doi:`10.1038/s41588-021-00783-5`_.

In addition, please remember to cite the other papers described in the `citations file`_.

.. _citations file: https://github.com/PGScatalog/pgsc_calc/blob/master/CITATIONS.md
.. _10.1038/s41588-021-00783-5: https://doi.org/10.1038/s41588-021-00783-5

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

The adaptation of the codebase and nextflow implementation is written by
Benjamin Wingfield with input and supervision from Samuel Lambert (PGS Catalog)
and Aoife McMahon (EBI). Development of new features, testing, and code review
is ongoing including Inouye lab members (Rodrigo Canovas) and others. A
manuscript describing the tool is in preparation (see `Citations <Citations_>`_)

Others
~~~~~~

This pipeline uses code and infrastructure developed and maintained by the
`nf-core`_ community, reused here under the `MIT license`_:

    The nf-core framework for community-curated bioinformatics pipelines.

    Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes
    Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven
    Nahnsen.

    Nat Biotechnol. 2020 Feb 13. doi: 10.1038/s41587-020-0439-x.

This work has received funding from EMBL-EBI core funds, the Baker Institute,
the University of Cambridge, Health Data Research UK (HDRUK), and the European
Union’s Horizon 2020 research and innovation programme under grant agreement No
101016775 INTERVENE.

.. _MIT license: https://github.com/nf-core/tools/blob/master/LICENSE
.. _nf-core: https://nf-co.re


Data references
~~~~~~~~~~~~~~~

The pipeline is distributed with and uses a licensed dataset for testing:

- `CC-BY-NC-SA <https://creativecommons.org/licenses/by-nc-sa/4.0/>`_: `CINECA synthetic cohort Europe CH SIB <https://doi.org/10.5281/zenodo.5082689>`_

A subset of variants was sampled from the original CINECA synthetic European
cohort to create the test dataset. It's up to end-users to ensure that their use
of test data conforms to the license restrictions.
