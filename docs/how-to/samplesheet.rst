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

   * - sampleset
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

The file should be in :term:`CSV` format. A template is `available here`_ (right
click the link and "save as" to download).

There are five mandatory columns. Columns that specify genomic data paths
(**vcf_path**, **bfile_path**, and **pfile_path**) are mutually exclusive:

- **sampleset**: A text string referring to the name of a :term:`target dataset` of
  genotyping data containing at least one sample/individual (however cohort datasets
  will often contain many individuals with combined genotyped/imputed data). Data from a
  sampleset may be input as a single file, or split across chromosomes into multiple files.
  Scores generated from files with the same sampleset name are combined in later stages of the
  analysis.
- **vcf_path**: A text string of a file path pointing to a multi-sample
  :term:`VCF` file. File names must be unique. It's best to use full file paths,
  not relative file paths.
- **bfile_path**: A text string of a file path pointing to the prefix of a plink
  binary fileset. For example, if a binary fileset consists of plink.bed,
  plink.bim, and plink.fam then the prefix would be "plink". Must be
  unique. It's best to use full file paths, not relative file paths.
- **pfile_path**: Like **bfile_path**, but for a PLINK2 format fileset (pgen /
  psam / pvar)
- **chrom**: An integer (range 1-22) or string (X, Y). If the target genomic data file contains
  multiple chromosomes, leave empty. Don't use a mix of empty and integer
  chromosomes in the same sample.

.. _`available here`: https://raw.githubusercontent.com/PGScatalog/pgsc_calc/dev/assets/examples/samplesheet.csv


