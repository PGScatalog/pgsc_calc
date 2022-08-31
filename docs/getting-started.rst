:orphan:
   
.. _get started:

Get started
===========

``pgsc_calc`` requires Nextflow and one of Docker, Singularity, or Anaconda.

1. Start by `installing nextflow`_:

.. code-block:: console

    $ java -version # Java v8+ required
    openjdk 11.0.13 2021-10-19

    $ curl -fsSL get.nextflow.io | bash

    $ mv nextflow ~/bin/

2. Next, `install Docker`_, `Singularity`_, or `Anaconda`_

3. Finally, check Nextflow is working:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc --help
    N E X T F L O W  ~  version 21.04.0
    Launching `pgscatalog/pgsc_calc` [condescending_stone] - revision: cf3e5c886b [master]
    ...

And check if Docker, Singularity, or Anaconda are working by running the
workflow with bundled test data and replacing ``<docker/singularity/conda>`` in the command below
with the specific container manager you intend to use:

.. code-block:: console
                
    $ nextflow run pgscatalog/pgsc_calc -profile test,<docker/singularity/conda>
    ... <configuration messages intentionally not shown> ...
    ------------------------------------------------------
    If you use pgscatalog/pgsc_calc for your analysis please cite:

    * The Polygenic Score Catalog
      https://doi.org/10.1038/s41588-021-00783-5

    * The nf-core framework
      https://doi.org/10.1038/s41587-020-0439-x

    * Software dependencies
      https://github.com/pgscatalog/pgsc_calc/blob/master/CITATIONS.md
    ------------------------------------------------------
    executor >  local (7)

    [49/d28766] process > PGSC_CALC:PGSCALC:INPUT_CHECK:SAMPLESHEET_JSON (samplesheet.csv)           [100%] 1 of 1 ✔
    [c3/a8e0d9] process > PGSC_CALC:PGSCALC:INPUT_CHECK:SCOREFILE_CHECK                              [100%] 1 of 1 ✔
    [-        ] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:PLINK2_VCF                               -
    [7c/5cca6c] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:PLINK2_BFILE (cineca_synthetic_subset)   [100%] 1 of 1 ✔
    [3b/ce0e39] process > PGSC_CALC:PGSCALC:MAKE_COMPATIBLE:MATCH_VARIANTS (cineca_synthetic_subset) [100%] 1 of 1 ✔
    [2e/fb3233] process > PGSC_CALC:PGSCALC:APPLY_SCORE:PLINK2_SCORE (cineca_synthetic_subset)       [100%] 1 of 1 ✔
    [b5/fc5b1e] process > PGSC_CALC:PGSCALC:APPLY_SCORE:SCORE_REPORT (1)                             [100%] 1 of 1 ✔
    [03/009cb6] process > PGSC_CALC:PGSCALC:DUMPSOFTWAREVERSIONS (1)                                 [100%] 1 of 1 ✔
    -[pgscatalog/pgsc_calc] Pipeline completed successfully-
    

.. _`installing nextflow`: https://www.nextflow.io/docs/latest/getstarted.html
.. _`install Docker`: https://docs.docker.com/engine/install/
.. _`Singularity`: https://sylabs.io/guides/3.0/user-guide/installation.html
.. _`Anaconda`: https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html

.. note:: Replace ``<docker/singularity/conda>`` with what you have installed on
          your computer (e.g., ``docker``, ``singularity``, or ``conda``). These
          options are mutually exclusive!

Calculate your first polygenic scores
=====================================

If you've completed the installation process that means you've already
calculated some polygenic scores |:heart_eyes:| However, these scores were
calculated using synthetic data from a single chromosome. Let's try calculating scores
with your genomic data, which are probably genotypes from real people!

.. warning:: You might need to prepare input genomic data before calculating
           polygenic scores, see :ref:`prepare`

1. Samplesheet setup
--------------------

First, you need to describe the structure of your genomic data in a standardised
way. To do this, set up a spreadsheet that looks like one of the examples below:

.. list-table:: Example bfile samplesheet
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - sampleset
     - vcf_path
     - bfile_path
     - pfile_path
     - chrom
   * - cineca_synthetic_subset
     -
     - /full/path/to/bfile_prefix
     -
     - 22
   * - cineca_synthetic_subset
     -
     - /full/path/to/bfile_prefix
     -
     - 21

.. list-table:: Example multi-chromosome bfile samplesheet
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - sampleset
     - vcf_path
     - bfile_path
     - pfile_path
     - chrom
   * - cineca_synthetic_subset
     -
     - /full/path/to/bfile_prefix
     -
     - 
     
.. list-table:: Example split VCF samplesheet
   :widths: 20 20 20 20 20
   :header-rows: 1

   * - sampleset
     - vcf_path
     - bfile_path
     - pfile_path
     - chrom
   * - cineca_synthetic_subset_vcf
     - /full/path/to/vcf.gz     
     -
     -
     - 22
   * - cineca_synthetic_subset_vcf
     - /full/path/to/vcf.gz
     -       
     -
     - 21       
       
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

Save this spreadsheet in :term:`CSV` format (e.g., ``samplesheet.csv``). An
example template is `available here`_.

.. _`available here`: https://github.com/PGScatalog/pgsc_calc/blob/master/assets/examples/example_data/bfile_samplesheet.csv

2. Select scoring files
-----------------------

pgsc_calc makes it simple to work with polygenic scores that have been published
in the PGS Catalog. You can specify one or more scores using the ``--accession``
parameter:

.. code-block:: console

    --accession PGS001229 # one score
    --accession PGS001229,PGS001405 # many scores separated by , (no spaces)
        
If you would like to use a custom scoring file not published in the PGS Catalog,
that's OK too (see :ref:`calculate custom`).

Users are required to specify the genome build that to their genotyping calls are in reference
to using the ``--target_build`` parameter. The ``--target_build`` parameter only supports builds
``GRCh37`` (*hg19*) and ``GRCh38`` (*hg38*).

.. code-block:: console

    --accession PGS001229,PGS001405 --target_build GRCh38

In the case of the example above, both ``PGS001229`` and ``PGS001405`` are reported in genome build GRCh37.
In cases where the build of your genomic data are different from the original build of the PGS Catalog score
then the pipeline will download a `harmonized (remapped rsIDs and/or lifted positions)`_  versions of the
scoring file(s) in the user-specified build.

Custom scoring files can be lifted between genome builds using the ``--liftover`` flag, (see :ref:`liftover`
for more information). An example would look like:

.. code-block:: console

    ---scorefile MyPGSFile.txt --target_build GRCh38

.. _harmonized (remapped rsIDs and/or lifted positions): https://www.pgscatalog.org/downloads/#dl_ftp_scoring_hm_pos
    
3. Putting it all together
--------------------------

For this example, we'll assume that the input genomes are in build GRCh37 and that
they match the scoring file genome build.

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile <docker/singularity/conda> \
        --input samplesheet.csv --target_build GRCh37 \
        --accession PGS001229

Congratulations, you've now (`hopefully`) calculated some scores!
|:partying_face:|

After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/score/`` directory in your current
working directory (``$PWD``) by default. If you're interested in more
information, see :ref:`interpret`.

If the workflow didn't execute successfully, have a look at the
:ref:`troubleshoot` section. Remember to replace ``<docker/singularity/conda>``
with the software you have installed on your computer.

4. Next steps & advanced usage
------------------------------

The pipeline distributes with settings that easily allow for it to be run on a
personal computer on smaller datasets (e.g. 1000 Genomes, HGDP).

For information on how to run the pipelines on larger datasets/computers/job-schedulers,
see :ref:`big job`.

If you are using an newer Mac computer with an M-series chip, see :ref:`arm`.
