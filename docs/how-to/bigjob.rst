.. _big job:

How do I run `pgsc_calc` on larger datasets and more powerful computers?
========================================================================

If you want to calculate many polygenic scores for a very large dataset (e.g. UK BioBank)
you will likely need to adjust the pipeline settings. You might have access to a powerful workstation,
a University cluster, or some cloud compute resources. This section will show how to set up
`pgsc_calc` to submit work to these types of systems by creating and editing `nextflow .config files`_.

.. _nextflow .config files: https://www.nextflow.io/docs/latest/config.html

Configuring `pgsc_calc` to use more resources locally
-----------------------------------------------------

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
resources used. Assuming the configuration file you set up is saved as
``my_custom.config`` in your current working directory, you're ready to run
pgsc_calc:

.. code-block:: console
                
    $ nextflow run pgscatalog/pgsc_calc \
        -profile <docker/singularity/conda> \
        --input samplesheet.csv \
        --accession PGS001229 \
        -c my_custom.config

High performance computing cluster
----------------------------------

If you have access to a HPC cluster, you'll need to configure your cluster's
unique parameters to set correct queues, user accounts, and resource
limits.

.. note:: Your institution may already have `a nextflow profile`_ with existing cluster settings
          that can be adapted instead of setting up a custom config using ``-c``

However, in general you will have to adjust the ``executor`` options and job resource
allocations (e.g. ``process_low``). Here's an example for an LSF cluster:

.. code-block:: text

    process {
        executor = 'lsf'
        queue = 'short'
        clusterOptions = ''
        scratch = true

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
            maxForks = 25
        }       
    }

In SLURM, queue is equivalent to a partition. Specific cluster parameters can be
provided by modifying ``clusterOptions``. You should change ``cpus``,
``memory``, and ``time`` to match the amount of resources used. Assuming the
configuration file you set up is saved as ``my_custom.config`` in your current
working directory, you're ready to run pgsc_calc. Instead of running nextflow
directly on the shell, save a bash script (``run_pgscalc.sh``) to a file
instead:

.. code-block:: bash
                
    export NXF_ANSI_LOG=false
    export NXF_OPTS="-Xms500M -Xmx2G" 
    
    module load nextflow-21.10.6-gcc-9.3.0-tkuemwd
    module load singularity-3.7.0-gcc-9.3.0-dp5ffrp

    nextflow run pgscatalog/pgsc_calc \
        -profile singularity \
        --input samplesheet.csv \
        --accession PGS001229 \
        -c my_custom.config

.. note:: The name of the nextflow and singularity modules will be different in
          your local environment

.. note:: Think about enabling fast variant matching with ``--fast_match``!      
          
.. code-block:: console
            
    $ bsub -M 2GB -q short -o output.txt < run_pgscalc.sh

This will submit a nextflow driver job, which will submit additional jobs for
each process in the workflow. The nextflow driver requires up to 4GB of RAM
(bsub's ``-M`` parameter) and 2 CPUs to use (see a guide for `HPC users`_ here).

.. _`LSF and PBS`: https://nextflow.io/docs/latest/executor.html#slurm
.. _`HPC users`: https://www.nextflow.io/blog/2021/5_tips_for_hpc_users.html
.. _`a nextflow profile`: https://github.com/nf-core/configs


Other environments
------------------

Nextflow also supports submitting jobs platforms like:

- Google cloud (https://www.nextflow.io/docs/latest/google.html)
- Azure cloud (https://www.nextflow.io/docs/latest/azure.html)
- Amazon cloud (https://www.nextflow.io/docs/latest/aws.html)
- Kubernetes (https://www.nextflow.io/docs/latest/kubernetes.html)
  
Check the `nextflow documentation`_ for configuration specifics.

.. _`nextflow documentation`: https://nextflow.io/docs/latest/
