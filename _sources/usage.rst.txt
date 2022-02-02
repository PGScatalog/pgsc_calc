Usage
=====

This page describes some typical use cases of the workflow.

.. warning:: Target genomic data must be in build 37 currently
   
Calculating scores with a VCF file
----------------------------------

Firstly, prepare a samplesheet in CSV format with the following structure:

.. list-table:: Example samplesheet: ``example_vcf.csv``
   :widths: 25 25 25 25
   :header-rows: 1

   * - sample
     - vcf_path
     - bfile_path
     - chrom
   * - cineca_synthetic_subset_vcf
     - path/to/vcf.gz
     - 
     - 22

An example samplesheet is available to download `here <https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/bfile_samplesheet.csv>`_.       
Secondly, download a polygenic score from the `PGS Catalog`_ and decompress it.

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_vcf.csv \
        --scorefile example_scorefile.txt

.. _`PGS Catalog`: https://www.pgscatalog.org/

Calculating scores with plink binary filesets
---------------------------------------------

Plink 1 `binary filesets`_ must consist of three files:

- A binary biallelic genotype table (e.g. ``example.bed``)
- A plink extended MAP file (e.g. ``example.bim``)
- A plink sample information file (e.g. ``example.fam``)
  
The only change in the samplesheet structure is to specify the path to the
binary fileset prefix, which is the name of the fileset before the file extension
(e.g. "example"). The samplesheet should have the following structure:

.. list-table:: Example samplesheet: ``example_bfile.csv``
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

An example samplesheet is available to download `here <https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/bfile_samplesheet.csv>`_.

Secondly, download a polygenic score from the `PGS Catalog`_ and decompress it.

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_bfile.csv \
        --scorefile example_scorefile.txt

.. _`binary filesets`: https://www.cog-genomics.org/plink2/formats#bed

Calculating scores with multiple files
--------------------------------------
