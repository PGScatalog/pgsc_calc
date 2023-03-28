Reference: container images
===========================

The recommended way of running ``pgsc_calc`` requires downloading and running
container images that we have built and hosted in publicly available container
registries. The container images contain software that we need to calculate
scores. Below is a list of container images for reference, which might be
helpful if you'd like to download and inspect them manually.

Software
--------

.. note:: Up to 6 containers are currently required to run ``pgsc_calc``.
   4 containers are required if you choose not to run ancestry assignment.

Minimum required software:

* `plink2 2.00a3.3`_
    * Used to work with target genomes and to calculate scores
* `pyyaml`_
    * Used to collect and report software versions used across the pipeline
* `pgscatalog_utils`_
    * A collection of useful tools for working with PGS Catalog data
* report
    * Contains R, RMarkdown, and the tidyverse to produce the summary report

Ancestry assignment software:

* `fraposa_pgsc`_
    * A method of robustly predicting the ancestry of target genomes by
      projecting them into a PCA space derived from reference genomes
* `zstd`_
    * A fast lossless compression algorithm, used to compress and decompress
      reference data, and natively supported by ``plink2``

.. _`plink2 2.00a3.3`: https://www.cog-genomics.org/plink/2.0/
.. _`pyyaml`: https://pypi.org/project/PyYAML/
.. _`pgscatalog_utils`: https://github.com/PGScatalog/pgscatalog_utils
.. _`fraposa_pgsc`: https://github.com/PGScatalog/fraposa_pgsc
.. _`zstd`: https://github.com/facebook/zstd

Downloading and inspecting containers
-------------------------------------

Production versions of docker and singularity containers are hosted on the PGS
Catalog Github `package registry`_.

Singularity images have ``-singularity`` appended to container tags.

Docker images support ``linux/amd64`` and ``linux/arm64`` platforms.

Information about the specific container versions that ``pgsc_calc`` is using is
stored in the ``conf/modules.config`` file.

.. _`package registry`: https://github.com/orgs/PGScatalog/packages
