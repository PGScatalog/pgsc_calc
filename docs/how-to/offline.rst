.. _offline:

How do I run pgsc_calc in an offline environment?
=================================================

``pgsc_calc`` has been deployed on secure platforms like Trusted Research
Environments (TREs), including UK Biobank and All of Us.

To run ``pgsc_calc`` in an offline environment you'll need Docker or Apptainer/Singularity installed on the offline computer.

On a computer with internet access you'll need to download:

1. A container
2. Scoring files that you want to run
3. (Optionally) Reference data

And transfer these to your offline environment.

Every computing environment has different quirks and it can be difficult to get
everything working correctly. Please feel free to `open a discussion on Github`_
if you are having problems and we'll try our best to help you.

.. _open a discussion on Github: https://github.com/PGScatalog/pgsc_calc/discussions

Download container image
------------------------

We publish a special docker image that contains every dependency to `simplify installation`_.

.. _simplify installation: https://hub.docker.com/repository/docker/pgscatalog/pgsc_calc/general

We also provide a `singularity image`_.

.. _singularity image: https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_calc_v2_blob.sif

In this container the calculator must be run with the conda profile, because conda environments have been installed and configured for you.

Docker
~~~~~~

Pull and save the docker image to a tar file in an online environment:

.. code-block:: bash

   $ docker pull pgscatalog/pgsc_calc:v2-blob
   $ docker save pgscatalog/pgsc_calc:v2-blob > pgsc_calc.tar

Transfer this file to your offline environment and load it:

.. code-block:: bash

   $ docker load pgsc_calc.tar

Singularity
~~~~~~~~~~~

Download our singularity image.

.. code-block:: bash

  $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_calc_v2_blob.sif


And transfer the directory to your offline environment.

Download scoring files
----------------------

.. tip:: Use our CLI application ``pgscatalog-download`` to `download multiple scoring`_ files in parallel and the correct genome build

.. _download multiple scoring: https://pygscatalog.readthedocs.io/en/latest/how-to/guides/download.html

You'll need to preload scoring files in the correct genome build.
Using PGS001229 as an example:

https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS001229/ScoringFiles/

.. code-block:: bash

  $ PGS001229/ScoringFiles
    ├── Harmonized
    │   ├── PGS001229_hmPOS_GRCh37.txt.gz <-- the file you want
    │   ├── PGS001229_hmPOS_GRCh37.txt.gz.md5
    │   ├── PGS001229_hmPOS_GRCh38.txt.gz <-- or perhaps this one!
    │   └── PGS001229_hmPOS_GRCh38.txt.gz.md5
    ├── PGS001229.txt.gz
    ├── PGS001229.txt.gz.md5
    └── archived_versions

These files can be transferred to the offline environment and provided to the
workflow using the ``--scorefile`` parameter.

.. tip:: If you're using multiple scoring files you must use quotes
         e.g. ``--scorefile "path/to/scorefiles/PGS*.txt.gz"``

(Optional) Download reference data
-----------------------------------

If you want to liftover a custom scoring file to a different genome build you'll need to download chain files.

* ``--hg19_chain`` https://hgdownload.cse.ucsc.edu/goldenpath/hg19/liftOver/hg19ToHg38.over.chain.gz
* ``--hg38_chain`` https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/hg38ToHg19.over.chain.gz

Scoring files from the PGS Catalog Calculator that are downloaded using ``pgscatalog-download`` with the ``--build`` parameter set don't need to be lifted over. They are already in the correct genome build.

If you want to do ancestry-based score normalisation you'll need to download the reference
panel too. See :ref:`norm` for more details.

.. console::

  $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_HGDP+1kGP_v1.tar.zst # combined reference panel, preferred
  $ wget https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_1000G_v1.tar.zst # or only 1000 Genomes

Running the calculator test profile in an interactive job
----------------------------------------------------------

Running the test profile is important to make sure the calculator is installed correctly on your computer.

The examples below are for apptainer/singularity, but the approach is similar for docker.

For both the docker and singularity container all dependencies are preinstalled and the calculator must be run using the conda profile.

Assuming you're using a HPC that's running SLURM, start an interactive job:

.. code-block:: bash

  $ salloc --cpus-per-task=2 --mem=16G --time=01:00:00
  $ singularity shell --bind $PWD:$PWD pgsc_calc_v2_blob.sif
  $ nextflow run /opt/pgsc_calc/main.nf -profile conda,test --outdir $PWD/results

This will run the test profile inside the container, publishing results to your current working directory.

If you're able to run this step successfully, continue to testing real data in an interactive job.

Interactive job with real data
------------------------------

.. code-block:: bash

  $ salloc --cpus-per-task=2 --mem=16G --time=01:00:00
  $ singularity shell --bind $PWD:$PWD —-bind /path/to/data:/path/to/data pgsc_calc_v2_blob.sif
  $ nextflow run /opt/pgsc_calc/main.nf -profile conda --outdir $PWD/results --input $PWD/samplesheet.csv --scorefile "$PWD/path/to/scorefiles.txt" --target_build GRCh38

The key differences here are that:

* The directory containing target genomes is mounted inside the singularity container
* Remember to set up the samplesheet
* Set target build and path to local scoring files (use pgscatalog-download if it's helpful!)

If this works interactively, larger jobs can be submitted to the batch job system.

Batch job with real data
------------------------

This example is useful if you're running very large or long running jobs on a HPC.

Create a batch job script::

  #!/bin/bash
  #SBATCH --job-name=pgsc_calc   # Name of the job
  #SBATCH --output=pgsc_calc.out # Output file
  #SBATCH --error=pgsc_calc.err  # Error file
  #SBATCH --ntasks=1         	# Number of tasks
  #SBATCH --cpus-per-task=4  	# Number of CPUs
  #SBATCH --mem=64G          	# Memory per node
  #SBATCH --time=02:00:00    	# Time limit (adjust as necessary)

  # Load Singularity module (if needed)
  module load singularity

  # Define paths
  SIF_IMAGE="pgsc_calc_v2_blob.sif"
  BIND_DIRS="$PWD:$PWD,/path/to/data:/path/to/data"

  # Run the Singularity container and execute the commands
  singularity exec --bind $BIND_DIRS $SIF_IMAGE bash <<'EOF'
  # Inside the container
  nextflow run /opt/pgsc_calc/main.nf \
    -profile conda \
    --outdir $PWD/results \
    --input $PWD/samplesheet.csv \
    --scorefile "$PWD/path/to/scorefiles.txt" \
    --target_build GRCh38
  EOF

