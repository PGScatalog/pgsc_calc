.. _multiple:

How to apply multiple scores in parallel
========================================

pgsc_calc makes it simple to scale up polygenic score calculation by using PLINK
2's built-in matrix multiplication. If you want to calculate multiple scores for
your genetic data it will always be faster to run the pipeline once with the
parallel method described in this section. Running the workflow many times, once
for each score, will be much slower |:man_running:|

1. Samplesheet setup
--------------------

First, you need to describe the structure of your genomic data in a standardised
way. To do this, set up a spreadsheet that looks like:

.. list-table:: Example samplesheet
   :widths: 25 25 25 25
   :header-rows: 1

   * - sample
     - vcf_path
     - bfile_path
     - chrom
   * - cineca_synthetic_subset
     -
     - path/to/bfile_prefix
     - 22
   * - cineca_synthetic_subset_vcf
     - path/to/vcf.gz
     - 
     - 22

Save the file as ``samplesheet.csv``. See :ref:`setup samplesheet` for more details.

2. Multiple PGS Catalog scores
------------------------------

It's simple to run multiple scoring files published in the PGS Catalog. Each
entry in the PGS Catalog has an accession that starts with the prefix PGS. The
``--accession`` parameter supports multiple entries. List each PGS accession,
separating each accession with commas (no whitespace):

.. code-block:: console

    --accession PGS001229,PGS001405

That's all you need to do! |:partying_face:|

In this simple example all PGS Catalog accessions are scoring files in build
GRCh37. You might find that some scores don't match the genome build of your
genomic data as you use more scores. To make sure all scores match the build of
your genomic data, you'll need to set some additional parameters (see
:ref:`liftover`).

3. Multiple custom scorefiles
-----------------------------

You might have set up multiple custom scorefiles (see :ref:`calculate
custom`). The ``--scorefile`` parameter supports multiple scorefile paths by
using star characters (``*``). If your custom scorefiles are in the
directory ``my_custom_scores/``:

.. code-block:: console

    --scorefile "my_custom_scores/*.tsv"

Assuming your scorefiles all have a ``.tsv`` extension. This will match **all**
files ending with ``.tsv``, so be careful not to include other text files that
may match the pattern.

Two stars (``**``) will match across multiple directories. This can be useful if
your scoring files have a structure like:

.. code-block:: console

    $ tree diabetes/
    diabetes/
    ├── type1
    │   └── type1.tsv
    └── type2
        └── type2.tsv

    2 directories, 2 files

In this case, using two stars with the scorefile parameter can be helpful:

.. code-block:: console

    --scorefile "diabetes/**.tsv"

.. note:: - Custom scorefiles **must** have unique filenames
          - The basename of each file (e.g. ``type1.tsv`` -> ``type1``) is used
            to label the score in the workflow output
          - Quotes around stars (``"*.tsv"``) are important for matching to work as expected

Setting multiple scores in one custom scoring file
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The examples above assume each scoring file contains a single score. A single
custom scoring file can contain multiple scores by using a different scoring
file template. The final column effect_weight can be repeated if every column
has a suffix:

.. list-table:: Scorefile with multiple effect weights
   :widths: 20 20 20 20 
   :header-rows: 1

   * - chr_name
     - ...
     - effect_weight_type1
     - effect_weight_type2
   * - 22
     - ...
     - 0.01045457
     - 0.02000000

The columns chr_position, effect_allele, and other_allele are left out (...) in
the example table to save space, but are mandatory (see :ref:`custom scorefile
setup`). Multiple score columns **must** follow the pattern
effect_weight_suffix, where suffix is a label for each score. Suffixes **must**
be unique.

Setting effect types for variants is not supported with this format (see
:ref:`effect type`). An example template is available here. 

4. Calculate!
-------------

- If you're using multiple scores from the PGS Catalog:
  
.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        --input samplesheet.csv \
        --accession PGS001229,PGS001405

- Or you might be using multiple scoring files in the same directory:

.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        --input samplesheet.csv \
        --scorefile "my_custom_scores/*.tsv"    

Congratulations, you've now calculated multiple scores in parallel!
|:partying_face:|

.. note:: You can set both ``--accession`` and ``--scorefile`` parameters to
          combine scores in the PGS Catalog with your own custom scores

After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/make/`` directory by default. If
you're interested in more information, see :ref:`interpret`.

If the workflow didn't execute successfully, have a look at the
:ref:`troubleshoot` section. 

