.. _prepare:

How do I prepare my input genomes?
==================================

The pipeline checks target genomic data to make sure it's consistent with the
data that's described in the samplesheet (see :ref:`setup samplesheet`).

Only human chromosomes 1 -- 22, X, Y, and XY are supported by the pipeline,
although sex chromosomes are rarely used in scoring files. If input data contain
other chromosomes (e.g. pseudoautosomal regions) then the pipeline will probably
complain loudly and stop calculating.

The simplest way to prepare your input data is to use the `plink2`_ ``--chr``
flag to create a new dataset that only contains compatible chromosomes. The
process is slightly different depending on the format of your target genomes.

VCF
---

.. code-block:: console

    plink2 --vcf <full_path_to_vcf.vcf.gz> \
        --allow-extra-chr \
        --chr 1-22, X, Y, XY \
        -make-pgen --out <1000G>_axy


``plink`` binary fileset (bfile)
--------------------------------

.. code-block:: console

    plink2 --bfile <path_to_bfile_prefix> \
        --allow-extra-chr \
        --chr 1-22, X, Y, XY \
        -make-pgen --out <prefix>_axy


``plink2`` binary fileset (pfile)
---------------------------------

.. note:: The pipeline will be much faster if you convert your input data to pfile
          format
          
.. code-block:: console
                
    plink2 --pfile <path_to_pfile_prefix> \
        --allow-extra-chr \
        --chr 1-22, X, Y, XY \
        -make-pgen --out <prefix>_axy


.. warning:: Don't forget to replace paths in ``<brackets>`` with your own data!

.. _`plink2`: https://www.cog-genomics.org/plink/2.0/filter
