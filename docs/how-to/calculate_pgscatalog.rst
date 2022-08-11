.. _calculate pgscatalog:

How to use scoring files in the PGS Catalog
===========================================

The easiest way to calculate a polygenic score is to use a scoring file that's
been published in the `PGS Catalog`_!

1. Samplesheet setup
--------------------

First, you need to describe the structure of your genomic data in a standardised
way. To do this, set up a spreadsheet that looks like:

.. list-table:: Example samplesheet
   :widths: 25 25 25 25
   :header-rows: 1

   * - sample
     - vcf_path
     - bfile_path
     - chrom
   * - cineca_synthetic_subset
     -
     - path/to/bfile_prefix
     - 22
   * - cineca_synthetic_subset_vcf
     - path/to/vcf.gz
     - 
     - 22

Save the file as ``samplesheet.csv``. See :ref:`setup samplesheet` for more details.

.. _`PGS Catalog`: http://www.pgscatalog.org/

2. Pick scores from the PGS Catalog 
-----------------------------------

Accessions
~~~~~~~~~~

Individual scores can be used by using Polygenic Score IDs that start with with
the prefix "PGS". For example, `PGS001229`_. The parameter ``--accession``
accepts polygenic score IDs:

.. code-block:: console

    --accession PGS001229

Multiple scores can be set by using a comma separated list:

.. code-block:: console

    --accession PGS001229,PGS000802

.. _`PGS001229`: http://www.pgscatalog.org/score/PGS001229/

Traits
~~~~~~

If you would like to calculate every polygenic score in the Catalog for a
`trait`_, like `coronary artery disease`_, then you can use the ``--trait``
parameter:

.. code-block:: console

    --trait EFO_0001645

Multiple traits can be set by using a comma separated list.

.. _`trait`: https://www.pgscatalog.org/browse/traits/
.. _`coronary artery disease`: https://www.pgscatalog.org/trait/EFO_0001645/


Publications
~~~~~~~~~~~~

If you would like to calculate every polygenic score associated with a
`publication`_ in the PGS Catalog, you can use the ``--publication`` parameter:

.. code-block:: console

    --publication PGP000001

Multiple traits can be set by using a comma separated list.

.. _`publication`: https://www.pgscatalog.org/browse/studies/

.. note:: Accessions, traits, and publications can be combined to calculate
          multiple polygenic scores.
          
3. Calculate!
-------------

.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        -profile <docker/singularity/conda> \    
        --input samplesheet.csv \
        --accession PGS001229

.. note:: For more details about calculating multiple scores, see :ref:`multiple` 

