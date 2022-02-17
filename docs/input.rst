Input
======

To calculate a polygenic score, you need to provide the workflow with two
inputs:

- :term:`target genomic data`
- a :term:`scoring file`, or a list of scoring files

At its simplest, target genomic data might be a single :term:`VCF` file or a
plink 1 binary fileset (i.e., bed / bim / fam). Larger and more complex datasets
might be split across multiple files, separated by chromosome. There are two
ways to specify the structure of target genomic data:

- A :term:`CSV` file (a "samplesheet")
- A :term:`JSON` file

Most people should use a CSV file, because they are easy to work with using
Excel or similar spreadsheet software. The use of samplesheets is quite popular
across `nf-core`_ pipelines.

.. _nf-core: https://nf-co.re/
   
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

.. _`available here`: https://github.com/PGScatalog/pgsc_calc/tree/master/assets/examples/samplesheet.csv

The documentation below is automatically generated from the input schema and
contains additional technical detail. 

.. jsonschema:: ../assets/schema_input.json
.. _`example`: https://github.com/PGScatalog/pgsc_calc/blob/master/assets/api_examples/input.json

Scoring files
-------------

PGS Catalog
~~~~~~~~~~~

The calculator natively supports scoring files submitted to the PGS Catalog
using the parameter ``--accession``. Setting this parameter means that the
calculator will query the PGS Catalog API and automatically fetch scoring
files. Multiple accessions can be specified using a comma separated list, e.g.:

.. code-block:: bash

  --accession PGS001229,PGS000014

Multiple accessions will be merged and processed in parallel. If you want to
calculate a lot of scores for your dataset, it's always more efficient to
specify multiple accessions and to run the calculator once (instead of running
the calculator multiple times, once per accession). Accessions should always
start with the prefix "PGS".

.. warning:: You MUST check that the PGS Catalog accession and target genomic
             data are in the same build (e.g. GrCh37) for your calculated scores
             to be biologically meaningful. We're working to support automatic
             build conversion.

.. _custom scoring:

Custom scoring files
~~~~~~~~~~~~~~~~~~~~

The calculator also supports using custom scoring files that haven't been
submitted to the PGS Catalog. The custom scorefile should have the following format:

.. list-table:: Scorefile template
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - chr_name
     - chr_position
     - effect_allele
     - other_allele
     - effect_weight
   * - 22
     - 17080378
     - G
     - A
     - 0.01045457

Where column names are defined in the PGS Catalog `scoring file format v2.0`_.
The file should be in tab separated values (TSV) format. Example `scorefile
templates`_ are available in the calculator repository. Two additional optional
columns can be set to specify the effect type of each variant:

.. list-table:: Optional effect type columns
   :widths: 50 50
   :header-rows: 1

   * - is_dominant
     - is_recessive
   * - TRUE
     - FALSE

These optional columns follow the structure described in the PGS Catalog
`scoring file format v2.0`_ and should be included after the effect_weight
column. Briefly, a variant with an additive effect type (the default if optional
columns are not set) is specified by setting both columns to FALSE. If the
variant effect type is recessive, set is_recessive to TRUE. If the variant
effect type is dominant, set is_dominant to TRUE. The columns are mutually
exclusive (a variant cannot be dominant and recessive).

The calculator can run using a custom scorefile with the ``--scorefile``
parameter (e.g. ``--scorefile path/to/scorefile.txt``. A custom scorefile can
only contain a single score. If you would like to calculate multiple scores in
parallel, include a wildcard (``*``) with the scorefile parameter
(e.g. ``--scorefile path/to/scorefiles/*.txt``). More detailed examples are
available in the :doc:`Usage </usage>` section of the documentation. 

.. _`scorefile templates`: https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/scorefiles
.. _`scoring file format v2.0`: https://www.pgscatalog.org/downloads/#scoring_header
