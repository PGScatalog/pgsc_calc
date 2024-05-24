.. _version:

How do I change the version or update ``pgsc_calc``?
====================================================

.. tip:: It's best to always use the most recent release, unless you're trying to reproduce an old analysis

I'm running the workflow from nextflow directly
------------------------------------------------

If you would like to use a specific version of ``pgsc_calc`` and are running
the pipeline using our Github repository you can use some of the default nextflow
parameters (see `-r command docs <https://www.nextflow.io/docs/latest/sharing.html#handling-revisions>`_).

To run a specific version:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile <docker/singularity/conda> -r [version name, e.g. v2.0.0-alpha.5] ....


To run the latest version of a previously cloned repository you can use ``nextflow pull`` or add the ``-latest`` flag to
a run command (see `nextflow docs <https://www.nextflow.io/docs/latest/cli.html#commands>`_):

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile <docker/singularity/conda> -latest ....

I used git to clone the repository
-----------------------------------

By default the main branch contains the most recent release. You can use older releases with git:

.. code-block:: console

    $ cd path/to/pgsc_calc
    $ git pull
    $ git tag
    ...
    v2.0.0-alpha.2
    v2.0.0-alpha.3
    v2.0.0-alpha.4
    v2.0.0-alpha.5
    $ git checkout v2.0.0-alpha.5

To switch back to the main branch:

.. code-block:: console

    $ cd path/to/pgsc_calc
    $ git pull
    $ git checkout main
