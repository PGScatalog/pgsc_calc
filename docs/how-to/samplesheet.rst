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

.. csv-table:: Example samplesheet
   :file: ../../assets/examples/samplesheet.csv
   :header-rows: 1
                 
The file should be in :term:`CSV` format. A template is :download:`available to
download here <../../assets/examples/samplesheet.csv>`.

There are four mandatory columns:

- **sampleset**: A text string referring to the name of a :term:`target dataset`
  of genotyping data containing at least one sample/individual (however cohort
  datasets will often contain many individuals with combined genotyped/imputed
  data). Data from a sampleset may be input as a single file, or split across
  chromosomes into multiple files.  Scores generated from files with the same
  sampleset name are combined in later stages of the analysis.

  .. danger::
     - ``pgsc_calc`` works best with cohort data
     - Scores calculated for low sample sizes will generate warnings in the
       output report
     - You should merge your genomes if they are split per individual before
       using ``pgsc_calc``
  
- **path_prefix** should be set to the path of the target genomes excluding all
  file extensions

  - Example path prefix: ``/home/stuff/data.vcf.gz`` -> ``/home/stuff/data``

  .. danger:: Always use absolute paths that begin with ``/``, e.g. ``/home/stuff/...``

  .. note:: One plink file set (``bed / bim / fam`` or ``pgen / pvar / psam``) only
       needs a single path prefix and row in the samplesheet
     
- **chrom**: An integer (range 1-22) or string (X, Y). If the target genomic
  data file contains multiple chromosomes, leave empty. Don't use a mix of empty
  and integer chromosomes in the same sample.

- **format**: The file format of the target genomes. Currently supports
  ``pfile``, ``bfile``, or ``vcf``.

.. note:: Multiple samplesheet rows are typically only needed if:
          
          - The target genomes are split to have a one file per chromosome
          - You're working with multiple cohorts simultaneously 
          
Setting genotype field
~~~~~~~~~~~~~~~~~~~~~~

.. note:: This is an optional process that is only applicable for some types of
          VCF data
          
There is one optional column:

- **vcf_genotype_field**: Genotypes present in :term:`VCF` files are extracted from the
  ``GT`` field (hard-called genotypes) by default. Oftentimes genotypes are imputed from
  from limited sets of genotyped variants (microarrays, low-coverage sequencing) using
  imputation tools (Michigan or TopMed Imputation Servers) that output dosages for the
  ALT allele(s): to extract these data users should enter ``DS`` in this column.

An example of a samplesheet with two VCF datasets where you'd like to import
different genotypes from each is below:

.. list-table:: Example samplesheet with genotype field set
   :header-rows: 1

   * - sampleset
     - path_prefix
     - chrom
     - format 
     - vcf_genotype_field       
   * - cineca_sequenced
     - path/to/vcf
     - 22
     - vcf
     - ``GT``
   * - cineca_imputed
     - path/to/vcf_imputed
     - 22
     - vcf
     - ``DS``

.. _`available here`: https://raw.githubusercontent.com/PGScatalog/pgsc_calc/dev/assets/examples/samplesheet.csv


