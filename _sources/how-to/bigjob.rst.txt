How do I run big jobs on a powerful computer?
=============================================

If you want to calculate many polygenic scores for a very large dataset, like
the UK BioBank, you might need some extra computing power! You might have access
to a powerful workstation, a University cluster, or some cloud compute
resources. This section will show how to set up pgsc_calc to submit work to
these types of systems.

Configuring pgsc_calc to use more resources locally
---------------------------------------------------

If you have a powerful computer available locally, you can configure the amount
of resources that the workflow uses. 

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
limits. Here's an example for an LSF cluster:

.. code-block:: text

    process {
        executor = 'lsf'
        queue = 'short'
        clusterOptions = ''

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
    module load nextflow-21.10.6-gcc-9.3.0-tkuemwd
    module load singularity-3.7.0-gcc-9.3.0-dp5ffrp

    nextflow run pgscatalog/pgsc_calc \
        -profile singularity \
        --input samplesheet.csv \
        --accession PGS001229 \
        -c my_custom.config

.. note:: The name of the nextflow and singularity modules will be different in
          your local environment
          
.. note:: Your institution may already have `a nextflow profile`_, which can be
          used instead of setting up a custom config using ``-c``
          
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

- Google cloud
- Azure cloud
- Amazon cloud

Check the `nextflow documentation`_ for configuration specifics. pgsc_calc is
deployed and tested on a `local Kubernetes cluster`_, but it's not a recommended
way of running the pipeline for normal users.

.. _`nextflow documentation`: https://nextflow.io/docs/latest/google.html
.. _`local Kubernetes cluster`: https://github.com/PGScatalog/pgsc_calc/blob/master/conf/k8s.config
