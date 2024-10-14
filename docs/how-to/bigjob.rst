.. _big job:

How do I run ``pgsc_calc`` on larger datasets and more powerful computers?
==========================================================================

If you want to calculate many polygenic scores for a very large dataset (e.g. UK
BioBank) you will likely need to adjust the pipeline settings. You might have
access to a powerful workstation, a University cluster, or some cloud compute
resources. This section will show how to set up ``pgsc_calc`` to submit work to
these types of systems by creating and editing `nextflow .config files`_.

.. _nextflow .config files: https://www.nextflow.io/docs/latest/config.html

.. warning:: ``--max_cpus`` and ``--max_memory`` don't increase the amount of
             resources for each process. These parameters **cap the maximum
             amount of resources** `a process can use`_. You need to edit
             configuration files to increase process resources, as described
             below.

.. _`a process can use`: https://github.com/PGScatalog/pgsc_calc/issues/71#issuecomment-1423846928

Configuring ``pgsc_calc`` to use more resources locally
-------------------------------------------------------

If you have a powerful computer available locally, you can configure the amount
of resources that each job in the workflow uses.

.. code-block:: text

    process {
        executor = 'local'
        
        withLabel:process_low {
            cpus   = 2
            memory = 8.GB
            time   = 1.h
        }
        withLabel:process_medium {
            cpus   = 8
            memory = 64.GB
            time   = 4.h
        }
        withName: PLINK2_SCORE {
            maxForks = 4
        }
    } 

You should change ``cpus``, ``memory``, and ``time`` to match the amount of
resources you have available. The values provided are a sensible starting point
for very large datasets.  Assuming the configuration file you set up is saved as
``my_custom.config`` in your current working directory, you're ready to run
pgsc_calc:

.. code-block:: console
                
    $ nextflow run pgscatalog/pgsc_calc \
        -profile <docker/singularity/conda> \
        --input samplesheet.csv \
        --pgs_id PGS001229 \
        -c my_custom.config


High performance computing cluster
----------------------------------

If you have access to a HPC cluster, you'll need to configure your cluster's
unique parameters to set correct queues, user accounts, and resource
limits.

.. note:: Your institution may already have `a nextflow profile`_ with existing
          cluster settings that can be adapted instead of setting up a custom
          config using ``-c``

.. warning:: You'll probably want to use ``-profile singularity`` on a HPC. The
          pipeline requires Singularity v3.7 minimum.
   
Here's an example configuration running about 100 scores in parallel
on UK Biobank with a SLURM cluster:

.. code-block:: text

    process {
      errorStrategy = 'retry'
      maxRetries = 3
      maxErrors = '-1'
      executor = 'slurm'

      withName: 'SAMPLESHEET_JSON' {
        cpus = 1
        memory = { 1.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'DOWNLOAD_SCOREFILES' {
        cpus = 1
        memory = { 1.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'COMBINE_SCOREFILES' {
        cpus = 1
        memory = { 16.GB * task.attempt }
        time = { 2.hour * task.attempt }
      }

      withName: 'PLINK2_MAKEBED' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'RELABEL_IDS' {
        cpus = 1
        memory = { 16.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'PLINK2_ORIENT' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'DUMPSOFTWAREVERSIONS' {
        cpus = 1
        memory = { 1.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'ANCESTRY_ANALYSIS' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'SCORE_REPORT' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'EXTRACT_DATABASE' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'PLINK2_RELABELPVAR' {
        cpus = 1
        memory = { 16.GB * task.attempt }
        time = { 2.hour * task.attempt }
      }

      withName: 'INTERSECT_VARIANTS' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'INTERSECT_THINNED' {
        cpus = 1
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'MATCH_VARIANTS' {
        cpus = 2
        memory = { 32.GB * task.attempt }
        time = { 6.hour * task.attempt }
      }

      withName: 'FILTER_VARIANTS' {
        cpus = 1
        memory = { 16.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'MATCH_COMBINE' {
        cpus = 2
        memory = { 64.GB * task.attempt }
        time = { 6.hour * task.attempt }
      }

      withName: 'FRAPOSA_PCA' {
        cpus = 2
        memory = { 8.GB * task.attempt }
        time = { 1.hour * task.attempt }
      }

      withName: 'PLINK2_SCORE' {
        cpus = 2
        memory = { 8.GB * task.attempt }
        time = { 16.hour * task.attempt }
      }
  }


.. note:: You'll want to adjust memory usage depending on the complexity of your input scoring files.  Allocating more CPUs probably won't make the workflow complete faster. 

Assuming the configuration file you set up is saved as
``my_custom.config`` in your current working directory, you're ready
to run pgsc_calc. Instead of running nextflow directly on the shell,
save a bash script (``run_pgscalc.sh``) to a file instead:

.. code-block:: bash

    #SBATCH -J ukbiobank_pgs
    #SBATCH -c 1
    #SBATCH -t 24:00:00
    #SBATCH --mem=2G
    
    export NXF_ANSI_LOG=false
    export NXF_OPTS="-Xms500M -Xmx2G" 
    
    module load nextflow-21.10.6-gcc-9.3.0-tkuemwd
    module load singularity-3.7.0-gcc-9.3.0-dp5ffrp

    nextflow run pgscatalog/pgsc_calc \
        -profile singularity \
        --input samplesheet.csv \
        --pgs_id PGS001229 \
        -c my_custom.config

.. note:: The name of the nextflow and singularity modules will be different in
          your local environment

.. warning:: Make sure to copy input data to fast storage, and run the
            pipeline on the same fast storage area. You might include
            these steps in your bash script. Ask your sysadmin for
            help if you're not sure what this means.
          
.. code-block:: console
            
    $ sbatch run_pgsc_calc.sh
    
This will submit a nextflow driver job, which will submit additional jobs for
each process in the workflow. The nextflow driver requires up to 4GB of RAM and 2 CPUs to use (see a guide for `HPC users`_ here).

.. _`HPC users`: https://www.nextflow.io/blog/2021/5_tips_for_hpc_users.html
.. _`a nextflow profile`: https://github.com/nf-core/configs


Cloud deployments
-----------------

We've deployed the calculator to Google Cloud Batch but some :doc:`special configuration is required<cloud>`.
