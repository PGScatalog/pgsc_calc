Installation
============

``pgsc_calc`` is made with Nextflow and the nf-core framework. Nextflow needs to
be present on the computer where you want to launch the analysis. The latest
installation `instructions are available here`_. The only hard requirement for
Nextflow is an Unix operating system and Java:

.. _`instructions are available here`: https://www.nextflow.io/docs/latest/getstarted.html#installation

.. code-block:: bash

    # Make sure that Java v8+ is installed:
    java -version

    # Install Nextflow
    curl -fsSL get.nextflow.io | bash

    # Add Nextflow binary to your user's PATH:
    mv nextflow ~/bin/
    # OR system-wide installation:
    # sudo mv nextflow /usr/local/bin

Adding nextflow `to your PATH`_ is important so you are able to run nextflow in
a terminal outside of the directory that the downloaded binary is in. If your
operating system don't add ``~/bin/`` to your PATH automatically, so you might
need to configure this yourself.

.. _`to your PATH`: https://unix.stackexchange.com/a/26059

.. note::
   You can update nextflow by running ``nextflow self-update``

Workflow software
-----------------

``pgsc_calc`` needs a lot of different software to run. Instead of manually
installing each piece of dependent software, the workflow supports automatic
software packaging to improve reproducibility. The workflow supports Docker,
Singularity, and Conda:

- `Docker`_
    - Normally used on a local computer or the cloud
    - Runs software inside `containers`_
    - Traditionally requires system root access, and rootless Docker is
      difficult to work with
- `Singularity`_
    - Often used instead of Docker on multi-user HPC systems
    - Runs software inside `containers`_
- `Conda`_
    - A packaging system that manages environments
    - Doesn't use containers, so worse reproducibility than Docker or
      Singularity
    - Recommended only as a fallback if Docker or Singularity aren't available

``pgsc_calc`` uses the nf-core framework, so has theoretical support for
`podman`_, `charliecloud`_, and `shifter`_, but these software packaging tools
aren't tested.

.. _`containers`: https://biocontainers-edu.readthedocs.io/en/latest/what_is_container.html
.. _`charliecloud`: https://hpc.github.io/charliecloud/
.. _`shifter`: https://www.nersc.gov/research-and-development/user-defined-images/
.. _`podman`: https://podman.io/
.. _`Docker`: https://docs.docker.com/get-docker/
.. _`Singularity`: https://sylabs.io/
.. _`Conda`: https://conda.io

Workflow code
-------------

Nextflow will automatically fetch ``pgsc_calc`` from Github, so you don't have
to do anything else. This process requires an internet connection.

If you would like to run the workflow on a computer with no internet connection,
please see the :doc:`offline instructions<offline>`.

To test everything is working well, run:

.. code-block:: bash

    nextflow run pgscatalog/pgsc_calc -profile test,docker

Replacing ``docker`` with ``singularity`` or ``conda`` as needed. This will
download the workflow and run it using a small test dataset. If this runs
without any errors, you're ready to try :doc:`your own data<usage>`. 
