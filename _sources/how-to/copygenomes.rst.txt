How to get a copy of the standardised genomic data
==================================================

pgsc_calc works with genomic data in a lot of formats. An important part of the
workflow is to standardise the genomic data for matching against scoring
files. These data can be large, and aren't published by default to the results
directory (i.e. with the scores and other output of the workflow). If you would
like a copy of the standardised genomic data, set the following parameter at
runtime:

.. code-block:: console

    --copy_genomes

.. warning::

   This can:
       - Give you a very big results directory
       - Make pgsc_calc slower, because it will spend extra time copying data

.. note::
    - If you used PLINK2 format input, you will get back PLINK2 format data
    - If you used PLINK1 format input, you will get back PLINK1 format data
    - If you used a VCF file, you will get back PLINK2 format data           

You might also find it useful to explore the nextflow working directory to check
PLINK logs or other intermediate output. By default, intermediate files are kept
in the ``work/`` directory. To find files, check the terminal output for
directory labels or use the ``find`` utility, e.g.:

.. code-block:: console

    $ nextflow run pgscatalog/pgsc_calc -profile test,docker
    $ find work/ -name '*.bim'
    work/stage/f7/d9451685e9db7e6c19ec48490ef275/cineca_synthetic_subset.bim
    work/27/ef1706eb5c99316b6e44200f2c1ba1/cineca_synthetic_subset.bim
    work/27/ef1706eb5c99316b6e44200f2c1ba1/cineca_synthetic_subset_22.bim
    work/5b/bc29aaf02d3695edfabb11488faf69/cineca_synthetic_subset_22.bim

Working directory labels (e.g. ``27/ef17..``) will probably be different on your
computer.
    
