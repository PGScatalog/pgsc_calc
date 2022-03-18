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
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - sample
     - vcf_path
     - bfile_path
     - pfile_path
     - chrom
   * - cineca_synthetic_subset
     -
     - path/to/bfile_prefix
     -
     - 22
   * - cineca_synthetic_subset_vcf
     - path/to/vcf.gz
     -
     -
     - 22

The file should be in :term:`CSV` format. A template is `available here`_.

There are five mandatory columns. Columns that specify genomic data paths
(**vcf_path**, **bfile_path**, and **pfile_path**) are mutually exclusive:

- **sample**: A text string containing the name of a dataset, which can be split
  across multiple files. Scores generated from files with the same sample name
  are combined in later stages of the analysis.
- **vcf_path**: A text string of a file path pointing to a multi-sample
  :term:`VCF` file. File names must be unique.
- **bfile_path**: A text string of a file path pointing to the prefix of a plink
  binary fileset. For example, if a binary fileset consists of plink.bed,
  plink.bim, and plink.fam then the prefix would be "plink". Must be unique.
- **pfile_path**: Like **bfile_path**, but for a PLINK2 format fileset (pgen /
  psam / pvar)  
- **chrom**: An integer, range 1-22. If the target genomic data contains
  multiple chromosomes, leave empty.

.. _`available here`: https://github.com/PGScatalog/pgsc_calc/blob/dev/assets/examples/samplesheet.csv 

