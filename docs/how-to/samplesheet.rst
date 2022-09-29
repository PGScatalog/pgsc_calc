.. _setup samplesheet:

How to set up a samplesheet
===========================

A samplesheet describes the structure of your input genotyping datasets. It's needed
because the structure of input data can be very different across use cases (e.g.
different file formats, directories, and split vs. unsplit by chromosome).

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

There are five mandatory columns:

- **sampleset**: A text string referring to the name of a :term:`target dataset` of
  genotyping data containing at least one sample/individual (however cohort datasets
  will often contain many individuals with combined genotyped/imputed data). Data from a
  sampleset may be input as a single file, or split across chromosomes into multiple files.
  Scores generated from files with the same sampleset name are combined in later stages of the
  analysis.
- Columns that specify genomic data paths (**vcf_path**, **bfile_path**, and **pfile_path**)
  are mutually exclusive and must contain only one non-NULL entry:
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

There is one optional column:

- **vcf_genotype_field**: Genotypes present in :term:`VCF` files are extracted from the
  ``GT`` field (hard-called genotypes) by default. Oftentimes genotypes are imputed from
  from limited sets of genotyped variants (microarrays, low-coverage sequencing) using
  imputation tools (Michigan or TopMed Imputation Servers) that output dosages for the
  ALT allele(s): to extract these data users should enter ``DS`` in this column.

An example of a samplesheet with two VCF datasets where you'd like to import
different genotypes from each is below:

.. list-table:: Example samplesheet
   :widths: 15 15 15 15 15 15
   :header-rows: 1

   * - sampleset
     - vcf_path
     - vcf_genotype_field
     - bfile_path
     - pfile_path
     - chrom
   * - cineca_sequenced
     - path/to/vcf.gz
     - ``GT``
     -
     -
     - 22
   * - cineca_imputed
     - path/to/vcf_imputed.gz
     - ``DS``
     -
     -
     - 22

.. _`available here`: https://raw.githubusercontent.com/PGScatalog/pgsc_calc/dev/assets/examples/samplesheet.csv


