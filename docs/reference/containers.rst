Reference: container images
===========================

The recommended way of running ``pgsc_calc`` requires downloading and running
container images that we have built and hosted. The container images contain
software that we need to calculate scores. Below is a list of container images
for reference, which might be helpful if you'd like to download and inspect them
manually.

.. note:: 4 containers are currently required to run ``pgsc_calc``

Docker
-------------

.. include:: ../_build/docker_containers.txt
    :literal:


Some containers are made by `Biocontainers`_, and hosted on their container
registry.

* `plink2 2.00a3.3`_
    * Used to work with target genomes and to calculate scores
* `multiqc`_
    * Used to collect and report software versions (only the ``pyyaml`` library
      is used from the ``multiqc`` image)

Other containers are hosted on a Gitlab container registry:

* `pgscatalog_utils`_
    * A collection of useful tools for working with PGS Catalog data
* report
    * Contains R, RMarkdown, and the tidyverse to produce the summary report
          
.. _`Biocontainers`: https://biocontainers.pro
.. _`plink2 2.00a3.3`: _`https://www.cog-genomics.org/plink/2.0/`
.. _`multiqc`: https://quay.io/repository/biocontainers/multiqc?tab=info
.. _`pgscatalog_utils`: https://github.com/PGScatalog/pgscatalog_utils


Choosing a container architecture
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. note:: Remember to replace ``${params.platform}`` with ``amd64`` or ``arm64``
          in the image tag

* We build separate docker images for ``arm64`` and ``amd64`` architectures,
  because multi-arch builds caused some problems with our container registry
* Biocontainers and Bioconda currently only support ``amd64``, so they're not
  tagged with an architecture

  
Singularity
-----------

.. include:: ../_build/singularity_containers.txt
    :literal:
       
.. note:: Singularity images are built from the docker images.

To download singularity images run:       

.. code-block:: console

                $ singularity pull <url>


.. warning:: We only build singularity images for ``amd64``
