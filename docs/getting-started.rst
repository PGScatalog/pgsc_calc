:orphan:

.. _get started:

Getting started
===============

``pgsc_calc`` has a few important software dependencies:

* Nextflow
* Docker, Singularity, or Anaconda
* Linux or macOS

Without these dependencies installed you won't be able to run ``pgsc_calc``.

Step by step setup
------------------

1. `Install nextflow`_:

.. code-block:: console

    $ java -version # Java v8+ required
    openjdk 11.0.13 2021-10-19

    $ curl -fsSL get.nextflow.io | bash

    $ mv nextflow ~/bin/

2. Next, `install Docker`_, `Singularity`_, or `Anaconda`_ (Docker or
   Singularity are best)

3. Run the ``pgsc_calc`` test profile:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile test,<docker|singularity|conda>

.. _`Install nextflow`: https://www.nextflow.io/docs/latest/getstarted.html
.. _`install Docker`: https://docs.docker.com/engine/install/
.. _`Singularity`: https://sylabs.io/guides/3.0/user-guide/installation.html
.. _`Anaconda`: https://docs.conda.io/projects/conda/en/latest/user-guide/install/index.html

.. note:: Remember to replace ``<docker|singularity|conda>`` one of ``docker``, ``singularity``, or ``conda``

.. warning:: If you have an ARM processor (like Apple sillicon) please check :ref:`arm`      


Please note the test profile genomes are not biologically meaningful, won't
produce valid scores, and aren't compatible with scores on the PGS Catalog. We
provide these genomes to make checking installation and automated testing
easier.

Calculate your first polygenic scores
-------------------------------------

If you've completed the setup guide successfully then you're ready to calculate
scores with your genomic data, which are probably genotypes from real
people. Exciting!

.. warning:: The format of samplesheets changed in v2.0.0 to better accommodate
             extra file formats in the future
   
.. warning:: You might need to prepare input genomic data before calculating
           polygenic scores, see :ref:`prepare`

1. Set up samplesheet
~~~~~~~~~~~~~~~~~~~~~

First, you need to describe the structure of your genomic data in a standardised
way. To do this, set up a spreadsheet that looks like:

.. csv-table:: Example samplesheet for a combined plink2 file set
   :file: ../assets/examples/samplesheet_multichrom.csv
   :header-rows: 1

.. csv-table:: Example samplesheet for a plink2 file set split by chromosome
   :file: ../assets/examples/samplesheet.csv
   :header-rows: 1

.. csv-table:: Example samplesheet for a combined VCF file
   :file: ../assets/examples/samplesheet_multichrom_vcf.csv
   :header-rows: 1

See :ref:`setup samplesheet` for more details.


2. Select scoring files
~~~~~~~~~~~~~~~~~~~~~~~

pgsc_calc makes it simple to work with polygenic scores that have been published
in the PGS Catalog. You can specify one or more scores using the ``--pgs_id``
parameter:

.. code-block:: console

    --pgs_id PGS001229 # one score
    --pgs_id PGS001229,PGS001405 # many scores separated by , (no spaces)

.. note:: You can also select scores associated with traits (``--trait_efo``) and
          publications (``--pgp_id``)
          
If you would like to use a custom scoring file not published in the PGS Catalog,
that's OK too (see :ref:`calculate custom`).

Users are required to specify the genome build that to their genotyping calls are in reference
to using the ``--target_build`` parameter. The ``--target_build`` parameter only supports builds
``GRCh37`` (*hg19*) and ``GRCh38`` (*hg38*).

.. code-block:: console

    --pgs_id PGS001229,PGS001405 --target_build GRCh38

In the case of the example above, both ``PGS001229`` and ``PGS001405`` are reported in genome build GRCh37.
In cases where the build of your genomic data are different from the original build of the PGS Catalog score
then the pipeline will download a `harmonized (remapped rsIDs and/or lifted positions)`_  versions of the
scoring file(s) in the user-specified build of the genotyping datasets.

Custom scoring files can be lifted between genome builds using the ``--liftover`` flag, (see :ref:`liftover`
for more information). If your custom PGS was in GRCh37 an example would look like:

.. code-block:: console

    ---scorefile MyPGSFile.txt --target_build GRCh38 --liftover

.. _harmonized (remapped rsIDs and/or lifted positions): https://www.pgscatalog.org/downloads/#dl_ftp_scoring_hm_pos

3. (Optional) Download reference database
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To enable genetic ancestry similarity calculations and PGS normalisation,
download one of our pre-built reference databases:

.. code-block:: console

    $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_HGDP+1kGP_v1.tar.zst

This database contains a merged 1000 Genomes and Human Genome Diversity Project reference panel, and is the recommended default panel. 

You may prefer to use 1000 Genomes only:

    $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_1000G_v1.tar.zst

See :ref:`ancestry` for more details.

3. Putting it all together
~~~~~~~~~~~~~~~~~~~~~~~~~~

For this example, we'll assume that the input genomes are in build GRCh37 and that
they match the scoring file genome build.

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc \
        -profile <docker/singularity/conda> \
        --input samplesheet.csv --target_build GRCh37 \
        --pgs_id PGS001229 \
        --run_ancestry pgsc_HGDP+1kGP_v1.tar.zst

Congratulations, you've now (`hopefully`) calculated some scores!
|:partying_face:|

.. tip:: Don't include ``--run_ancestry`` if you didn't download the reference database
         
After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/score/`` directory in your current
working directory (``$PWD``) by default. If you're interested in more
information, see :ref:`interpret`.

If the workflow didn't execute successfully, have a look at the
:ref:`troubleshoot` section. Remember to replace ``<docker/singularity/conda>``
with the software you have installed on your computer.

         
4. Next steps & advanced usage
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The pipeline distributes with settings that easily allow for it to be run on a
personal computer on smaller datasets (e.g. 1000 Genomes, HGDP). The minimum
requirements to run on these smaller datasets are:

* Linux
    - 16GB RAM
    - 2 CPUs
* macOS
    - 32GB RAM
    - 2 CPUs

.. warning:: If you use macOS, Docker will use 50% of your memory at most by
             default. This means that if you have a Mac with 16GB RAM,
             ``pgsc_calc`` may run out of RAM (most likely during the variant
             matching step).

For information on how to run the pipelines on larger datasets/computers/job-schedulers,
see :ref:`big job`.

If you are running the pipeline multiple times on the same dataset (e.g. different sets of
PGS) you can speed the pipeline up by cacheing the genotype harmonization and ancestry steps,
see :ref:`cache`.

If you are using an newer Mac computer with an M-series chip, see :ref:`arm`.
