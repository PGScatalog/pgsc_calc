.. _calculate custom:

How to use a custom scoring file
================================

You might want to use a scoring file that you've developed using different
genomic data, or a scoring file somebody else made that isn't published in the
PGS Catalog.

Custom scoring files need to follow a specific format. The entire process of
using a custom scoring file is described below.

1. Samplesheet setup
~~~~~~~~~~~~~~~~~~~~

Set up a samplesheet as described in: :ref:`setup samplesheet`.

.. _custom scorefile setup:

2. Scorefile setup
~~~~~~~~~~~~~~~~~~

Setup your scorefile in a spreadsheet by concatenating the variant-information to a
minimal header in the following format:

Header::

    #pgs_name=metaGRS_CAD
    #pgs_id=metaGRS_CAD    
    #trait_reported=Coronary artery disease
    #genome_build=GRCh37

Variant-information:

.. list-table::
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - chr_name
     - chr_position
     - effect_allele
     - other_allele
     - effect_weight
   * - 1
     - 2245570
     - G
     - C
     - -2.76009e-02
   * - 8
     - 26435271
     - T
     - C
     - 1.95432e-02
   * - 10
     - 30287398
     - C
     - T
     - 1.82417e-02

.. tip:: If you're having trouble getting your scorefile working, see :download:`the example we use in our automatic tests <../../assets/examples/scorefiles/customgrch37.txt>`

Save the file as ``scorefile.txt``. The file should be in tab separated values
(TSV) format. Column names are defined in the PGS Catalog `scoring file format v2.0`_,
and key metadata (e.g. ``genome_build`` should be specificied in the header) to ensure
variant matching and/or liftover is consistent with the target genotyping data.
Example `scorefile templates`_ are available in the calculator repository. Scorefiles can be
compressed with gzip if you would like to save storage space (e.g. ``scorefile.txt.gz``).

This how to guide describes a simple scoring file. More complicated scoring
files need extra work:

- If you want to set up scoring files to calculate multiple scores in parallel
  see :ref:`multiple`
- If you would like to set up a scoring file containing different effect types,
  see :ref:`effect type`
- If the genome build the custom scoring file was developed with doesn't match
  the genome build of the new input genomes, see :ref:`liftover`

.. _`scorefile templates`: https://github.com/PGScatalog/pgsc_calc/tree/main/assets/examples/scorefiles
.. _`scoring file format v2.0`: https://www.pgscatalog.org/downloads/#scoring_header

.. note:: The ``other_allele`` column is optional but recommended
          
3. Calculate!
~~~~~~~~~~~~

Set the path of the custom scoring file with the ``--scorefile`` parameter:

.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        -profile <docker/singularity/conda> \    
        --input samplesheet.csv \
        --scorefile scorefile.txt

Congratulations, you've now calculated some scores using your custom scoring file! |:partying_face:|

After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/`` directory by default. If
you're interested in more information, see :ref:`interpret`.

If the workflow didn't execute successfully, have a look at the
:ref:`troubleshoot` section. 
