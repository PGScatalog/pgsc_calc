.. _cloud:

How do I launch pgsc_calc using cloud executors?
================================================

Nextflow provides native support for `cloud executors <https://www.nextflow.io/docs/latest/executor.html>`_, like:

* Amazon Web Services
* Google Cloud Platform
* Azure

.. note:: Nextflow also supports data in cloud storage when using local or cloud executors

Your genomes are in cloud storage
---------------------------------

The samplesheet CSV format doesn't support cloud storage, but you can create a JSON samplesheet:

.. code-block:: json

    [
        {
            "pheno": "gs://bucket/data/all_phase3.psam",
            "vcf_import_dosage": false,
            "variants": "gs://bucket/data/all_phase3.pvar.zst",
            "geno": "gs://bucket/data/all_phase3.pgen",
            "sampleset": "test",
            "chrom": null,
            "format": "pfile"
        }
    ]
                
The sanplesheet is a JSON array that contains a list of JSON objects. Each row in the CSV samplesheet corresponds to an element in the JSON array.

.. warning:: Unlike the CSV samplesheet full paths must always be specified, including URIs (``s3://...``)

The key differences between the CSV and JSON samplesheet fields are:

* ``pheno``: Path to sample information file: plink 1 fam files, plink 2 fam files, or the VCF path
* ``variants``: Path to variant information file: plink 1 bim, plink 2 pvar, or the VCF path
* ``geno``: Path to genoftype file: plink 1 bed, plink 2 pgen, or the VCF path
* ``chrom``: An optional string (not an integer!)

.. note:: If you're using VCF input, then the VCF path must be repeated for ``pheno``,  ``variants``, and ``geno``


Once your samplesheet is ready, you can use it with nextflow:

.. code-block:: bash

    $ nextflow run pgscatalog/pgsc_calc --input path/to/samplesheet.json --format json ...              

.. warning:: Don't forget ``--format json``

.. note:: ``gs://`` is for Google Cloud Storage. Check the Nextflow documentation for other `supported cloud storage systems and URIs <https://www.nextflow.io/docs/latest/amazons3.html>`_

Why do I need to use JSON?
~~~~~~~~~~~~~~~~~~~~~~~~~~

The CSV samplesheet parsing does some helpful things like:

* Making sure paths exist
* Detecting file extensions based on the file format
* Finding and using compressed variant information files and preferentially using this data

While aiming to be in a friendly Excel compatible format. Biologists
love Excel, and JSON can be a little bit scary. A limitation of the
approach is that it only works well with normal file systems, and
doesn't support object storage.

How do I configure my cloud executor?
-------------------------------------

We've tested and deployed ``pgsc_calc`` on Google Cloud Platform and Seqera Platform using Wave and Fusion file system.

Describing cloud configuration is out of scope for ``pgsc_calc`` documentation. It's best to check the `Nextflow documentation <https://www.nextflow.io/docs/latest/google.html>`_ instead.

Please feel free to `open an issue or start a discussion <https://github.com/pgscatalog/pgsc_calc>`_ if you experience problems running the workflow in the cloud.
