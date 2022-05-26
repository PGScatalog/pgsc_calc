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

You can also edit ``nextflow.config`` to configure cpu and memory permanently.

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

.. _`thanks to Rvtests`: http://zhanxw.github.io/rvtests/#input-files    
