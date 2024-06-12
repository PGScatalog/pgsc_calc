.. _matchrates:

Why do I get match rate errors?
===============================

When you're running the PGS Catalog Calculator you might see errors like:

.. code-block:: console

    pgscatalog.core.lib.pgsexceptions.ZeroMatchesError: All scores fail to meet match threshold 0.75

You might also see some scoring files in the report are coloured red, and are excluded from the output.

By default pgsc_calc will continue calculating if at least one score passes the **match rate threshold**, which is controlled by the ``--min_overlap`` parameter.

The default parameter is 0.75. This was chosen because in our experience the matching procedure will match very well or very badly. 

If things go badly, it's typically because a problem with input data (target genomes or scoring files).

What is matching?
-----------------

The calculator carefully checks that variants (rows) in a scoring file are present in your target genomes.

The matching procedure `is described in the preprint supplement <https://www.medrxiv.org/content/10.1101/2024.05.29.24307783v1.supplementary-material>`_. 

It's really important that the calculator can find the variants described in the scoring files in your target genomes.

The matching procedure never makes any changes to target genome data. 

Adjusting ``--min_overlap`` is a bad idea 
------------------------------------------

The aim of the PGS Catalog Calculator is to faithfully reuse scores submitted by authors to the PGS Catalog on new target genomes. 

If few variants in a published scoring file are present in a target genome, then the calculated score isn't a good representation of the original published score. 

When you evaluate the predictive performance of the score it's less likely to reproduce the metrics reported in the PGS Catalog too.

If you reduce ``--min_overlap`` then the calculator will output scores calculated with the remaining variants, **but these scores are not representative of the original data submitted to the PGS Catalog.**

Are your target genomes imputed? Are they WGS?
----------------------------------------------

The calculator assumes that variants were called from an imputed SNP array to increase variant density.

WGS data are not natively supported by the calculator. However, it's `possible to create compatible gVCFs from WGS data. <https://github.com/PGScatalog/pgsc_calc/discussions/123#discussioncomment-6469422>`_

In the future we plan to improve support for WGS.

Did you set the correct genome build?
-------------------------------------

The calculator will automatically grab scoring files in the correct genome build from the PGS Catalog. 

We first match variants by looking at genomic coordinates, which can differ across genome builds. 

If you're using custom scoring files, did you remember to enable liftover?

I'm still getting match rate errors. How do I figure out what's wrong?
----------------------------------------------------------------------

Problems with matching are normally because of problems with input data rather than the matching procedure. 

If you're trying to reproduce a specific score and are experiencing problems, then some manual work is required. 

Try checking the full variant matching log to see which variants are missing, which will be present in the work directory reported in the Nextflow error. 

It can be a good idea to manually search your target genotypes for missing variants to see what's happening. 