:orphan:
   
.. _troubleshoot:

Troubleshooting
===============

I get an error about variant matching
-------------------------------------

- Are your target genomes and the scoring file in compatible builds?
- ``--min_overlap`` defaults to 0.75 (75% of variants in scoring file must be
  present in target genomes). Try changing this parameter!

The workflow isn't using many resources (e.g. RAM / CPU)
--------------------------------------------------------

Did you forget to set ``--max_cpu`` or ``--max_memory?``

You can also edit ``nextflow.config`` to configure cpu and memory permanently. nf-core
provides a `set of example .config files`_, including examples for both institutional
compute clusters (e.g. Cambridge, Sanger) and cloud compute providers (e.g. Google, AWS Tower and Batch).

.. _set of example .config files : https://github.com/nf-core/configs

When I run the workflow I get an error about software not being installed
-------------------------------------------------------------------------

``pgsc_calc`` bundles dependencies using containers or conda. Did you remember
to specify ``-profile``? e.g. ``nextflow run pgscatalog/pgsc_calc -profile
docker,test``

Multiple profiles can be combined with a comma. The test profile is used only
for checking the pipeline is installed and working correctly.

I'm having problems with VCF input
----------------------------------

If you use a "chr" prefix in the chromosome column of your VCF, please remove
it. Here's a simple method to do this (`thanks to Rvtests`_):

.. code-block:: console

    (zgrep ^"#" $your_old_vcf; zgrep -v ^"#" $your_old_vcf | sed 's:^chr::ig' | sort -k1,1n -k2,2n) | bgzip -c > $your_vcf_file.gz

VCF file(s) containing variants on non-standard chromsomes or patches (e.g. chr1_gl000191_random) will also currently fail
our pipeline as it only takes human chromosomes as input (1-22, X, Y, XY). One way to remove these variants is to download
and run plink2 and convert your data to plink files that can be used with the calculator using the following command:

.. code-block:: console

    plink2 --vcf [yourfile] --allow-extra-chr --chr 1-22, X, Y, XY -make-pgen --out [yourfile]_axy

however other methods to filter these variants from VCFs also exist.

.. _`thanks to Rvtests`: http://zhanxw.github.io/rvtests/#input-files    
