.. _ancestry:

How do I normalise calculated scores across different genetic ancestry groups?
==============================================================================

Download reference data
-----------------------

The fastest method of getting started is to download our reference panel:

.. code-block:: console

    $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_calc.tar.zst

The reference panel is based on 1000 Genomes. It was originally downloaded from
the PLINK 2 `resources section`_. To minimise file size INFO annotations are
excluded. KING pedigree corrections were enabled.

.. _`resources section`: https://www.cog-genomics.org/plink/2.0/resources

Bootstrap reference data
~~~~~~~~~~~~~~~~~~~~~~~~

It's possible to bootstrap (create from scratch) the reference data from the
PLINK 2 data, which is how we create the reference panel tar. See
:ref:`database`

Genetic similarity analysis and score normalisation
----------------------------------------------------------

To enable genetic similarity analysis and score normalisation, just include the
``--run_ancestry`` parameter when running the workflow:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile test,docker \
        --run_ancestry path/to/reference/pgsc_calc.tar.zst

The ``--run_ancestry`` parameter requires the path to the reference database.
