Usage
=====

This page describes some typical use cases of the workflow.

.. warning:: You MUST check that the scorefile and target genomic data are in
             the same build (e.g. GrCh37) for your calculated scores to be
             biologically meaningful. We're working to support automatic build
             conversion.
   
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
     -

An example samplesheet is available to download `here
<https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/samplesheet.csv>`_.
Secondly, specify one or more PGS Catalog accessions. To specify multiple
accessions, use a comma separated list (with no spaces between accessions).

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_vcf.csv \
        --accession PGS001229,PGS000014

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
     - 

An example samplesheet is available to download `here
<https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/samplesheet.csv>`_.
Secondly, specify one or more PGS Catalog accessions. To specify multiple
accessions, use a comma separated list (with no spaces between accessions).

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_bfile.csv \
        --accession PGS001229,PGS000014 

.. _`binary filesets`: https://www.cog-genomics.org/plink2/formats#bed

Calculating scores with split genomic data
------------------------------------------

Sometimes your target genomic data might be split across multiple files. The
calculator supports this type of input data for data split by chromosome. To
work with split genomic data, add rows to the samplesheet (one per file) and
set the **chrom** column. For example:

.. list-table:: Example samplesheet: ``example_split_vcf.csv``
   :widths: 25 25 25 25
   :header-rows: 1

   * - sample
     - vcf_path
     - bfile_path
     - chrom
   * - cineca_synthetic_subset_vcf
     - path/to/1.vcf.gz
     -
     - 1
   * - ...
     - ...
     -
     - ...
   * - cineca_synthetic_subset_vcf
     - path/to/22.vcf.gz
     -
     - 22

You can include as many or as few chromosomes as you want. For example, if your
scoring file only includes variants across 3 chromosomes you can choose to
include only these three chromosomes. Omitting unused chromosomes will make the
calculator slightly faster.

Using custom scoring files
--------------------------

If you would like to use a scoring file not in the PGS Catalog, you will need to
format it correctly for the calculator. See the :ref:`custom scoring` section
for an explanation of the scoring file format. Once your scoring file is
prepared, simply replace the ``--accession`` parameter:

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_vcf.csv \
        --scorefile /path/to/scorefile.txt

The calculator can calculate multiple scores in parallel efficiently. Just
prepare multiple scoring files, and use a wildcard character (``*``) to set
multiple files:

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc \
        -profile docker \
        --input example_vcf.csv \
        --scorefile /path/to/scorefile/directory/*.txt

.. note:: It's a good idea to keep scorefiles in a separate and clean
          directory. If there are other text files (that aren't scores) in the
          same directory, then the calculator will try to use them and break!
          
.. warning:: The base name of the scoring file (e.g. ``depression.txt`` ->
             "depression") is important and used to label scores in the output
             report. Please use filenames you'll understand.
        
