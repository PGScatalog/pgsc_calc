Output
======

The location of the output directory is set by the ``--outdir`` parameter. By
default, the results are stored in ``./results/``. The results have the following
structure:

.. code-block:: bash

    $ tree -L 1 results/
    results/
    ├── combine
    ├── dumpsoftwareversions
    ├── make
    ├── match
    ├── pipeline_info
    ├── plink2
    ├── samplesheet
    └── scorefile

Report
------

A summary report is available in the `make/` directory. It should open in a web
browser.

The report contains polygenic scores for an extract of samples. The full
polygenic scores can be downloaded by clicking "Download calculated scores". The
text file is in `plink .sscore format`_. 

.. _`plink .sscore format`: http://www.cog-genomics.org/plink/2.0/formats#sscore

Logs
----

Logs that describe each stage of the workflow are available in the other
directories. These might be useful to check the number of variants present in
your target genomic data that are found in the scoring file, for example (see
``match/``).

Pipeline information
--------------------

Execution reports are available in the ``pipeline_info`` directory. These
reports describe the amount of resources (time / memory / CPU) used by each
stage of the workflow.
