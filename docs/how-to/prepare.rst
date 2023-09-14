.. _prepare:

How do I prepare my input genomes?
==================================

Target genome data requirements
-------------------------------

.. note:: This workflow will work best with the output of an imputation server
          like `Michigan`_ or `TopMed`_.

          If you'd like to input WGS genomes, some extra preprocessing steps are required.

.. _`Michigan`: https://imputationserver.sph.umich.edu/index.html           
.. _`TopMed`: https://imputation.biodatacatalyst.nhlbi.nih.gov/

- Only human chromosomes 1 -- 22, X, Y, and XY are supported by the pipeline,
  although sex chromosomes are rarely used in scoring files.
- If input data contain other chromosomes (e.g. patch regions) then
  the pipeline may complain loudly and stop calculating.


Supported file formats
~~~~~~~~~~~~~~~~~~~~~~

The following file formats are currently supported:

- VCF
- Plink 1 file set (``.bed / .bim / .fam``)
- Plink 2 file set (``.pgen / .pvar / .psam``)

Compressed input is supported and automatically detected. For example, bgzip
compression of VCF files, or zstd compression of plink2 variant information
files (``.pvar``).

VCF from an imputation server
-----------------------------

.. code-block:: console

    plink2 --vcf <full_path_to_vcf.vcf.gz> \
        --allow-extra-chr \
        --chr 1-22, X, Y, XY \
        -make-pgen --out <short name>_axy

.. note:: Non-standard chromosomes/patches should not cause errors in versions >v2.0.0-alpha.3;
    however, they will be be filtered out from the list of variants available for PGS scoring.

VCF from WGS
------------

See https://github.com/PGScatalog/pgsc_calc/discussions/123 for discussion about tools
to convert the VCF files into ones suitable for calculating PGS.


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
