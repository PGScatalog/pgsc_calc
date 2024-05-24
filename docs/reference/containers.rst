.. _containers:

Reference: container images
===========================

The recommended way of running ``pgsc_calc`` requires downloading and running
container images that we have built and hosted in publicly available container
registries. The container images contain software that we need to calculate
scores. The workflow normally automatically downloads and runs the required
containers. Below is a list of container images for reference, which might be
helpful if you'd like to download and inspect them manually.

Software
--------

.. note::
   - Up to 6 containers are currently required to run ``pgsc_calc``
   - Only 4 containers are required if you choose not to run ancestry assignment

Minimum required software:

* `plink2 2.00a3.3`_
    * Used to work with target genomes and to calculate scores
* `pyyaml`_
    * Used to collect and report software versions used across the pipeline
* `pgscatalog-utils`_
    * A collection of useful tools for working with PGS Catalog data
* report
    * Contains publishing tools to produce the summary report

Ancestry assignment software:

* `fraposa_pgsc`_
    * A method of robustly predicting the ancestry of target genomes by
      projecting them into a PCA space derived from reference genomes
* `zstd`_
    * A fast lossless compression algorithm, used to compress and decompress
      reference data, and natively supported by ``plink2``

.. _`plink2 2.00a3.3`: https://www.cog-genomics.org/plink/2.0/
.. _`pyyaml`: https://pypi.org/project/PyYAML/
.. _`pgscatalog-utils`: https://github.com/PGScatalog/pygscatalog
.. _`fraposa_pgsc`: https://github.com/PGScatalog/fraposa_pgsc
.. _`zstd`: https://github.com/facebook/zstd

Downloading containers
----------------------

Production versions of docker and singularity containers can be downloaded from
the PGS Catalog Github `package registry`_.

Singularity images have ``-singularity`` appended to container tags.

Docker images support ``linux/amd64`` and ``linux/arm64`` platforms.

.. _`package registry`: https://github.com/orgs/PGScatalog/packages

Versions
--------

Information about the specific versions that ``pgsc_calc`` is using is stored in
the :download:`conf/modules.config <../../conf/modules.config>` file:

.. include:: ../../conf/modules.config
   :start-after: container configuration
   :end-before: // output configuration
   :literal:

Software versions will change across different releases of ``pgsc_calc``. This
information is also included in the output path
``results/pipeline_info/versions.yml`` by default.
