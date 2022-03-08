.. _setup samplesheet:

How to set up a samplesheet
===========================

A samplesheet describes the structure of your input genomic data. It's needed
because the structure of input data can be very different across experiments,
and biologists love Excel!

Samplesheet
-----------

A samplesheet can be set up in a spreadsheet program, using the following
structure:

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

The file should be in :term:`CSV` format. A template is `available here`_.

There are four mandatory columns. Two columns, **vcf_path** and **bfile_path**,
are mutually exclusive and specify the genomic file paths:

- **sample**: A text string containing the name of a dataset, which can be split
  across multiple files. Scores generated from files with the same sample name
  are combined in later stages of the analysis.
- **vcf_path**: A text string of a file path pointing to a multi-sample
  :term:`VCF` file. File names must be unique.
- **bfile_path**: A text string of a file path pointing to the prefix of a plink
  binary fileset. For example, if a binary fileset consists of plink.bed,
  plink.bim, and plink.fam then the prefix would be "plink". Must be unique.
- **chrom**: An integer, range 1-22. If the target genomic data contains
  multiple chromosomes, leave empty.

.. _`available here`: https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/bfile_samplesheet.csv


