``pgsc_calc``'s documentation
=============================

.. toctree::
    :maxdepth: 2

    install
    input
    usage
    parameters
    output
    troubleshooting
    api
    offline
    glossary

Introduction
------------

``pgsc_calc`` is a bioinformatics best-practice analysis pipeline for applying
scoring files from the `Polygenic Score (PGS) Catalog
<https://www.pgscatalog.org/>`_ to target genotyped samples |:dna:|
|:partying_face:|

.. note::

   This project is under very active development and updates are frequent

Quick start
-----------

1. Install :doc:`Nextflow<install>`
2. Install `Docker`_ or `Singularity`_ for full reproducibility or `Conda`_ as a
   fallback
3. Run the workflow on a minimal test dataset using:

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc -profile test,docker

.. note:: The ``docker`` profile option can be replaced with ``singularity`` or
          ``conda`` depending on your local environment

.. _`Docker`: https://docs.docker.com/get-docker/
.. _`Singularity`: https://sylabs.io/
.. _`Conda`: https://conda.io

Workflow summary
----------------

- Optionally, fetch scoring files from the PGS Catalog API
- Convert target genomic data to plink 2 binary fileset format automatically
- Match variants in the scoring files against variants in the target genome
- Create a set of new scoring files from the matched variant data
- Calculate scores for each sample from each scoring file
- Produce a summary report

In the future, the calculator will include:

- Build conversion of scoring files
- Ancestry estimation
  
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

Data references
---------------

The pipeline is distributed with and uses a licensed dataset for testing:

- `CC-BY-NC-SA <https://creativecommons.org/licenses/by-nc-sa/4.0/>`_: `CINECA synthetic cohort Europe CH SIB <https://doi.org/10.5281/zenodo.5082689>`_

A subset of variants was sampled from the original CINECA synthetic European
cohort to create the test dataset. It's up to end-users to ensure that their use
of test data conforms to the license restrictions.

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
