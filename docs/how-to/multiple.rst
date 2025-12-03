.. _multiple:

How to apply multiple scores in parallel
========================================

pgsc_calc makes it simple to scale up polygenic score calculation. If you want
to calculate multiple scores for your genetic data it will always be faster to
run the pipeline once with the parallel method described in this
section. Running the workflow many times, once for each score, will be much
slower 🏃‍♂️

1. Samplesheet setup
--------------------

Set up a samplesheet as described in: :ref:`setup samplesheet`.

2. Multiple PGS Catalog scores
------------------------------

As described in :ref:`calculate pgscatalog`, use a comma separated list to
select multiple accessions, traits, or publications. The pipeline will
automatically query the PGS Catalog API, download unique scoring files in the
correct genome build, and use your target genomes to calculate scores. For
example:

.. code-block:: console

    --pgs_id PGS001229,PGS000802

.. note:: If you'd like to calculate hundreds of PGS Catalog scoring files
          simultaneously, it's easiest to store parameters in a text file
          instead of setting ``--pgs_id`` in a terminal. See :ref:`params file`.

3. Multiple custom scorefiles
-----------------------------

You might have set up multiple custom scorefiles (see :ref:`calculate
custom`). The ``--scorefile`` parameter supports multiple scorefile paths by
using star characters (``*``). If your custom scorefiles are in the
directory ``my_custom_scores/``:

.. code-block:: console

    --scorefile "my_custom_scores/*.txt"


.. tip:: Don't forget the quote marks ``"`` around the path

Assuming your scorefiles all have a ``.txt`` extension. This will match **all**
files ending with ``.txt``, so be careful not to include other text files that
may match the pattern.

Two stars (``**``) will match across multiple directories. This can be useful if
your scoring files have a structure like:

.. code-block:: console

    $ tree diabetes/
    diabetes/
    ├── type1
    │   └── type1.txt
    └── type2
        └── type2.txt

    2 directories, 2 files

In this case, using two stars with the scorefile parameter can be helpful:

.. code-block:: console

    --scorefile "diabetes/**.txt"

.. note:: - Custom scorefiles **must** have unique filenames
          - The basename of each file (e.g. ``type1.txt`` -> ``type1``) is used
            to label the score in the workflow output
          - Quotes around stars (``"*.txt"``) are important for matching to work as expected

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
        -profile <docker/singularity/conda> \
        --input samplesheet.csv \
        --pgs_id PGS001229,PGS001405

- Or you might be using multiple scoring files in the same directory:

.. code-block:: console

    $ nextflow run pgscatalog/pgscalc \
        -profile <docker/singularity/conda> \
        --input samplesheet.csv \
        --scorefile "my_custom_scores/*.txt"

Congratulations, you've now calculated multiple scores in parallel!
🥳

.. note:: You can set both ``--pgs_id`` and ``--scorefile`` parameters to
          combine scores in the PGS Catalog with your own custom scores

After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/`` directory by default. If
you're interested in more information, see :ref:`interpret`.

If the workflow didn't execute successfully, have a look at the
:ref:`troubleshoot` section.
