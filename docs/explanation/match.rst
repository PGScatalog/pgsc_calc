.. _matchrates:

Why do I get match rate errors?
===============================

When you're running the PGS Catalog Calculator you might see errors like:

.. code-block:: console

    pgscatalog.core.lib.pgsexceptions.ZeroMatchesError: All scores fail to meet match threshold 0.75

You might also see some scoring files in the report are coloured red, and are excluded from the output.

By default pgsc_calc will continue calculating if at least one score passes the **match rate threshold**, which is controlled by the ``--min_overlap`` parameter.

The default parameter is 0.75, this was chosen because on our experiences applying PGS to new cohorts where most scores will score better than this threshold. 

If scores match your target genome poorly it's typically because a problem with input data (target genomes or scoring files).

What is matching?
-----------------

The calculator carefully checks that variants (rows) in a scoring file are present in your target genomes.

The matching procedure `is described in supplement of our recent publication <https://www.nature.com/articles/s41588-024-01937-x#Sec6>`_.

The matching procedure never makes any changes to target genome data and only seeks to match variants in the scoring file to the genome.  

Adjusting ``--min_overlap`` is a bad idea 
------------------------------------------

The aim of the PGS Catalog Calculator is to faithfully recalculate scores submitted by authors to the PGS Catalog on new target genomes. 

If few variants in a published scoring file are present in a target genome, then the calculated score isn't a good representation of the original published score. 

When you evaluate the predictive performance of a score with low match rates it will be less likely to reproduce the metrics reported in the PGS Catalog.

If you reduce ``--min_overlap`` then the calculator will output scores calculated with the remaining variants, **but these scores may not be representative of the original data submitted to the PGS Catalog.**

.. _wgs:

Are your target genomes imputed? Are they WGS?
----------------------------------------------

The calculator assumes that target genotyping data were called from a limited number of markers on a genotyping array and imputed using a larger reference panel to increase variant density.

WGS data are not natively supported by the calculator (as homozygous REF sites are excluded from the variant sites). However, it's `possible to create compatible gVCFs from WGS data. <https://github.com/PGScatalog/pgsc_calc/discussions/123#discussioncomment-6469422>`_

In the future we plan to improve support for WGS.

Did you set the correct genome build?
-------------------------------------

The calculator will automatically grab scoring files in the correct genome build from the PGS Catalog. If match rates are low it may be because you have specified the wrong genome build. If you're using custom scoring files and the match rate is low it is possible that the ``--liftover`` command may have been omitted. 

I'm still getting match rate errors. How do I figure out what's wrong?
----------------------------------------------------------------------

Problems with matching are normally because of problems with input data rather than the matching procedure. 

If you're trying to reproduce a specific score and are experiencing problems, then some manual work is required. 

Try checking the full variant matching log to see which variants are missing, which will be present in the work directory reported in the Nextflow error. 

It can be a good idea to manually search your target genotypes for missing variants to see what's happening. 
