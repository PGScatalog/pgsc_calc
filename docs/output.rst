
.. _interpret:

``pgsc_calc`` Outputs & Results
===============================


The pipeline outputs are written to a results directory
(``--outdir`` default is ``./results/``) that contains three subdirectories:

- ``score/``: calculated PGS with summary report
- ``match/`` : scoring files and variant match metadata
- ``pipeline_info/`` : nextflow pipeline execution (memory, runtime, etc.)

``score/``
----------

Calculated scores are stored in a gzipped-text space-delimted text file called
``aggregated_scores`` that is labelled with the date/time (e.g. ``aggregated_scores_YYYY_MM_DD_HH_MM_SS.txt.gz``).
Each row represents an individual, and there should be at least three columns with the following headers:

- ``dataset``: the name of the input sampleset
- ``IID``: the identifier of each sample within the dataset
- ``[PGS NAME]_SUM``: reports the weighted sum of *effect_allele* dosages multiplied by their *effect_weight*
  for each matched variant in the scoring file. The column name will be different depending on the scores
  you have chosen to use (e.g. ``PGS000001_SUM``).

At least one score must be present in this file (the third column). Extra columns might be
present if you calculated more than one score, or if you calculated the PGS on a dataset with a
small sample size (n < 50, in this cases a column named ``[PGS NAME]_AVG`` will be added that
normalizes the PGS using the number of non-missing genotypes to avoid using allele frequency data
from the target sample).

Report
~~~~~~

A summary report is also available (``report.html``). The report should open in
a web browser and contains useful information about the PGS that were applied,
how well the variants match with the genotyping data, and some simple graphs
displaying the distribution of scores in your dataset(s) as a density plot.

.. image:: screenshots/Report_1_header.png
    :width: 400
    :alt: Example PGS Catalog Report: header sections

``match/``
----------

This directory contains the raw data that is summarised in the scoring
report. The log file is a :term:`CSV` that contains a row for each variant in
the combined input scoring files. This information might be useful to debug a
score that is causing problems. Columns contain information about how each
variant was matched against the target genomes:


.. list-table:: ``[sampleset]_log.csv`` metadata
    :widths: 20, 80
    :header-rows: 1

    * - ``column_name``
      - Description
    * - ``chr_name``
      - Chromosome name/number associated with the variant.
    * - ``chr_position``
      - Chromosomal position associated with the variant.
    * - ``effect_allele``
      - The allele that's dosage is counted (e.g. {0, 1, 2}) and multiplied by the variant's weight (effect_weight)
        when calculating score. The effect allele is also known as the 'risk allele'.
    * - ``other_allele``
      - The other non-effect allele(s) at the loci.
    * - ``effect_weight``
      - Value of the effect that is multiplied by the dosage of the effect allele (effect_allele) when
        calculating the score. Additional information on how the effect_weight was derived is in the weight_type
        field of the header, and score development method in the metadata downloads.
    * - ``effect_type``
      - Whether the dosage is calculated as additive ({0, 1, 2}), dominant ({0, 1}) or recessive ({0, 1}).
    * - ``accession``
      - Name of the scoring file.
    * - ``row_nr``
      - Line number of the variant with reference to the original scoring file (accession).
    * - ``ID``
      - Identifier of the matched variant.
    * - ``REF``
      - Matched variant: reference allele.
    * - ``ALT``
      - Matched variant: alternative allele.
    * - ``matched_effect_allele``
      - Which of the REF/ALT alleles is the effect_allele in the target dataset.
    * - ``match_type``
      - Record of how the scoring file variant ``effect_allele`` & ``other_allele`` (*if available*) match
        the REF/ALT orientation of the ID, and whether the variant had to be strand-flipped to acheive a match.
    * - ``is_multiallelic``
      - True/False flag indicating whether the matched variant is multi-allelic (multiple ALT alleles).
    * - ``ambiguous``
      - True/False flag indicating whether the matched variant is strand-ambiguous (e.g. A/T and C/G variants).
    * - ``duplicate``
      - True/False flag indicating whether multiple scoring file variants match a single target ID.
    * - ``best_match``
      - True/False flag indicating whether this candidate match is the best match for the scoring file variant (accession/row_nr).
    * - ``dataset``
      - Name of the sampleset/genotyping data.
    * - ``match_pass``
      - True/False flag indicating whether the current accession was included in the final scoring file(s).
    * - ``match_rate``
      - Percentage of variants in the current accession that match the target dataset, combined with minimum
        overlap flag to determine match_pass.


Processed scoring files are also present in this directory. Briefly, variants in
the scoring files are matched against the target genomes. Common variants across
different scores are combined (left joined, so each score is an additional
column). The combined scores are then partially split to overcome PLINK2
technical limitations (e.g. calculating different effect types such as dominant
/ recessive). Once scores are calculated from these partially split scoring
files, scores are aggregated to produce the final results in ``score/``.

``pipeline_info/``
------------------

Summary reports generated by nextflow describing the execution of the pipeline in
a lot of technical detail (see `nextflow tracing & visulisation`_ docs for more detail).
The execution report can be useful to see how long a job takes to execute, and how much
memory/cpu has been allocated (or overallocated) to specific jobs. The DAG is a visualization
of the pipline that may be useful to understand how the pipeline processes data and the ordering
of the modules.

.. _`nextflow tracing & visulisation`: https://www.nextflow.io/docs/latest/tracing.html
