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

2. Set PGS Catalog accession
----------------------------

First, search the `PGS Catalog`_ to find traits or studies you're interested
in. Once you've found something (e.g., standing height), note the Polygenic Score ID
that starts with with the prefix "PGS". For example, `PGS001229`_. The parameter
``--accession`` accepts polygenic score IDs:

.. code-block:: console

    --accession PGS001229

.. note:: If you've found a score but the genome build doesn't match your input
          genomes, :ref:`liftover` may be helpful
          
.. _`PGS001229`: http://www.pgscatalog.org/score/PGS001229/

3. Calculate!
-------------

.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        -profile <docker/singularity/conda> \    
        --input samplesheet.csv \
        --accession PGS001229

.. note:: If you want to use multiple scores, see :ref:`multiple` 

.. _limitations:

Limitations
-----------

Some scores in the PGS Catalog are not compatible with this workflow, including:

- Scores missing genomic coordinates (some use rsids instead)
- Some scores don't have genome build information. They may work OK with your
  genomic data, but lifting over will not work.
- Scores in genome builds older than GRCh37
