.. _liftover:

How to liftover scoring files to match your input genome build
==============================================================

pgsc_calc uses genomic coordinates to help match variants in the scoring file to
variants in your input genomic data. These coordinates may not match if scoring
files are developed in a different genome build. Luckily, it's fairly simple to
automatically remap coordinates (liftover) to different genome builds.

.. _liftover pgscatalog:

Lifting over PGS Catalog scoring files
--------------------------------------

PGS Catalog scoring files have additional metadata set in a `header`_. pgsc_calc
reads this metadata and can automatically liftover scoring files to match your
input data if you set the following additional parameters at runtime:

.. code-block:: console

    --liftover --target_build GRCh38

Where ``--target_build`` can be GRCh37 or GRCh38. Some scoring files in the PGS
Catalog do not contain genome build data and cannot be remapped, see
:ref:`limitations`.

Putting everything together for an example run, assuming the input genomic data
are in build GRCh38:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile <docker/singularity/conda> \    
        --input samplesheet.csv \
        --accession PGS001229 \
        --liftover \
        --target_build GRCh38

.. _`header`: https://www.pgscatalog.org/downloads/#scoring_header

Lifting over custom scoring files
---------------------------------

Custom scoring files need to include metadata in a `header`_, following the PGS
Catalog v2 file format standard. A single line can be included at the top of
your custom scoring file to set the genome build:

.. code-block:: console

    #genome_build=GRCh38

Valid genome builds are GRCh37 and GRCh38.     

Then use the same procedure described in :ref:`liftover pgscatalog` to
automatically remap a scoring file against your genomic data build.

.. note:: If you're calculating multiple scores (see :ref:`multiple`) and you
          want to liftover some of the scorefiles, then **all** scorefiles need
          genome builds set in the header
