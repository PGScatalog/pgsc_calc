Input
======

To calculate a polygenic score, you need to provide the workflow with two
inputs:

- :term:`target genomic data`
- a :term:`scoring file`

At its simplest, target genomic data might be a single :term:`VCF` file. Larger
and more complex datasets might be split across multiple files. There are two
ways to specify the structure of target genomic data:

- A :term:`CSV` file (a "samplesheet")
- A :term:`JSON` file

Most people should use a CSV file, because they are easy to work with using
Excel or similar spreadsheet software. The use of samplesheets is quite popular
across `nf-core`_ pipelines.

.. _nf-core: https://nf-co.re/

.. warning:: Genomic data must currently be in build 37, but we're working to
             support other builds ASAP
   
Samplesheet
-----------

The samplesheet method is specified using the ``--input`` parameter. The
``--format`` parameter defaults to "csv", so you don't need to set it unless you
are using JSON.

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

A template is `available here`_.

There are four mandatory columns. Two columns, **vcf_path** and **bfile_path**,
are mutually exclusive and specify the genomic files:

- **sample**: A text string containing the name of a sample/experiment, which
  can be split across multiple files. Scores generated from files with the same
  sample name are cominbed in later stages of the analysis.
- **vcf_path**: A text string of a file path pointing to a multi-sample
  :term:`VCF` file. File names must be unique.
- **bfile_path**: A text string of a file path pointing to the prefix of a plink
  binary fileset. For example, if a binary fileset consists of plink.bed,
  plink.bim, and plink.fam then the prefix would be "plink". Must be unique.
- **chrom**: An integer, range 1-22. If the target genomic data contains
  multiple chromosomes, leave empty.

.. _`available here`: https://github.com/PGScatalog/pgsc_calc/tree/master/assets/examples/example_data

The documentation below is automatically generated from the input schema and
contains additional technical detail. 

.. jsonschema:: ../assets/schema_input.json
.. _`example`: https://github.com/PGScatalog/pgsc_calc/blob/master/assets/api_examples/input.json

Scoring file
------------

Scoring files can be specified with ``--scorefile``, which must be a string of a
file path. Scorefiles must be:

- PGS Catalog `scoring file format v2.0`_
- Genome build 37

.. note:: We're adding support for custom scoring files, multiple scoring files,
          and build conversion very soon!

.. note:: ``--accession`` can be used to automatically fetch a scorefile via the
          PGS Catalog API. The ``--accession`` and ``-scorefile`` parameters are
          mututally exclusive.

.. _`scoring file format v2.0`: https://www.pgscatalog.org/downloads/#scoring_header      
