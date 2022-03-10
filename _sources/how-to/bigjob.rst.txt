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

    params {
        max_memory = 36.GB
        max_cpus = 8
        max_time = 12.h
    }

    process {
        withLabel:process_low {
            cpus   = { check_max( 2     * task.attempt, 'cpus'    ) }
            memory = { check_max( 12.GB * task.attempt, 'memory'  ) }
            time   = { check_max( 4.h   * task.attempt, 'time'    ) }
        }
        withLabel:process_medium {
            cpus   = { check_max( 6     * task.attempt, 'cpus'    ) }
            memory = { check_max( 36.GB * task.attempt, 'memory'  ) }
            time   = { check_max( 8.h   * task.attempt, 'time'    ) }
        }
    }

You should change ``cpus``, ``memory``, and ``time`` to match the amount of
resources used (don't forget to change ``max`` in the params block too).

Assuming the configuration file you set up is saved as ``my_custom.config`` in
your current working directory, you're ready to run pgsc_calc:

.. code-block:: console
                
    $ nextflow run pgscatalog/pgsc_calc \
        --input samplesheet.csv \
        --accession PGS001229 \
        -c my_custom.config

High performance computing cluster
----------------------------------

If you have access to a HPC cluster, you'll need to configure your cluster's
unique parameters to set correct queues, user accounts, and resource limits:

.. code-block:: text

    params {
        max_memory = 36.GB
        max_cpus = 8
        max_time = 12.h
    }

    process {
        executor = 'slurm'
        queue = 'standard'
        clusterOptions = ''

        withLabel:process_low {
            cpus   = { check_max( 2     * task.attempt, 'cpus'    ) }
            memory = { check_max( 12.GB * task.attempt, 'memory'  ) }
            time   = { check_max( 4.h   * task.attempt, 'time'    ) }
        }
        withLabel:process_medium {
            cpus   = { check_max( 6     * task.attempt, 'cpus'    ) }
            memory = { check_max( 36.GB * task.attempt, 'memory'  ) }
            time   = { check_max( 8.h   * task.attempt, 'time'    ) }
        }
    } 

In SLURM, queue is equivalent to a partition. Nextflow can support other
executors like `LSF and PBS`_. Other cluster parameters can be provided by
modifying ``clusterOptions``. You should change ``cpus``, ``memory``, and
``time`` to match the amount of resources used (don't forget to change ``max``
in the params block too).

Assuming the configuration file you set up is saved as ``my_custom.config`` in
your current working directory, you're ready to run pgsc_calc:

.. code-block:: console
                
    $ nextflow run pgscatalog/pgsc_calc \
        --input samplesheet.csv \
        --accession PGS001229 \
        -c my_custom.config

.. _`LSF and PBS`: https://nextflow.io/docs/latest/executor.html#slurm

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
