:orphan:

Changelog
---------

Versions follow `semantic versioning`_ (``major.minor.patch``). Breaking changes
will only occur in major versions with changes noted in this changelog.

.. _`semantic versioning`: https://semver.org/

pgsc_calc v2.0.0-alpha.6 (2024-05-24)
-------------------------------------

Improvements

* Migrate our custom python tools to new https://github.com/PGScatalog/pygscatalog packages

  * Reference / target intersection now considers allelic frequency and variant missingness to determine PCA eligibility

  * Downloads from PGS Catalog should be faster (async)

  * Package CLI and libraries `are now documented <https://pygscatalog.readthedocs.io/en/latest/?badge=latest>`_

* Update plink version to alpha 5.10 final 

* Add docs describing cloud execution 

* Add correlation test comparing calculated scores against known good scores

* When matching variants, matching logs are now written before scorefiles to improve debugging UX

* Improvements to PCA quality (ensuring low missingness and suitable MAF for PCA-eligble variants in target samples).

  *  This could allow us to implement MAF/missingness filters for scoring file variants in the future. 

Bug fixes

* Fix ancestry adjustment with VCFs
* Fix support for scoring files that only have one effect type column 
* Fix adjusting PGS with zero variance (skip them) 
* Check for reserved characters in sampleset names

pgsc_calc v2.0.0-alpha.5 (2024-03-19)
-------------------------------------

Improvements:

* Automatically mount directories inside singularity containers without setting any configuration
* Improve permanent caching of ancestry processes with --genotypes_cache parameter
* resync with nf-core framework
* Refactor combine_scorefiles

Bug fixes:

* Fix semantic storeDir definitions causing problems cloud execution (google batch)
* Fix missing DENOM values with multiple custom scoring files (score calculation not affected)
* Fix liftover failing silently with custom scoring files (thanks Brooke!)

Misc:

* Move aggregation step out of report

pgsc_calc v2.0.0-alpha.4 (2023-12-05)
-------------------------------------

Improvements:

* Give a more helpful error message when there's no valid variant matches found

Bug fixes:

* Fix retrying downloads from PGS Catalog
* Fix numeric sample identifiers breaking ancestry analysis
* Check for chr prefix in samplesheets and error 

pgsc_calc v2.0.0-alpha.3 (2023-10-02)
-------------------------------------

Improvements:

* Automatically retry scoring with more RAM on larger datasets
* Describe scoring precision in docs 
* Change handling of VCFs to reduce errors when recoding 
* Internal changes to improve support for custom reference panels

Bug fixes:

* Fix VCF input to ancestry projection subworkflow (thanks `@frahimov`_ and `@AWS-crafter`_ for patiently debugging)
* Fix scoring options when reading allelic frequencies from a reference panel (thanks `@raimondsre`_ for reporting the changes from v1.3.2 -> 2.0.0-alpha)
* Fix conda profile action

.. _`@frahimov`: https://github.com/PGScatalog/pgsc_calc/issues/172
.. _`@AWS-crafter`: https://github.com/PGScatalog/pgsc_calc/issues/155
.. _`@raimondsre`: https://github.com/PGScatalog/pgsc_calc/pull/139#issuecomment-1736313211

pgsc_calc v2.0.0-alpha.1 (2023-08-11)
-------------------------------------

This patch fixes a bug when running the workflow directly from github with the
test profile (i.e. without cloning first). Thanks to `@staedlern`_ for reporting the
problem.

.. _`@staedlern`: https://github.com/PGScatalog/pgsc_calc/issues/151

pgsc_calc v2.0.0-alpha (2023-08-08)
-----------------------------------

This major release features breaking changes to samplesheet structure to provide
more flexible support for extra genomic file types in the future. Two major new
features were implemented in this release:

- Genetic ancestry group similarity is calculated to a population reference panel
  (default: 1000 Genomes) when the ``--run_ancestry`` flag is supplied. This runs
  using PCA and projection implemented in the ``fraposa_pgsc (v0.1.0)`` package.
- Calculated PGS can be adjusted for genetic ancestry using empirical PGS distributions
  from the most similar reference panel population or continuous PCA-based regressions.

These new features are optional and don't run in the default workflow. Other features
included in the release are:

- Speed optimizations for PGS scoring (skipping allele frequency calculation)

pgsc_calc v1.3.2 (2023-01-27)
-----------------------------

This patch fixes a bug that made some PGS Catalog scoring files incompatible
with the pipeline. Effect weights were sometimes set to utf-8 strings instead of
floating point numbers, which caused an assertion error. Thanks to `@j0n-a`_ for
reporting the problem.

.. _`@j0n-a`: https://github.com/PGScatalog/pgsc_calc/issues/79

pgsc_calc v1.3.1 (2023-01-24)
-----------------------------

This patch fixes a bug that breaks the workflow if all variants in one or more
PGS scoring files match perfectly with the target genomes. Thanks to
`@lemieuxl`_ for reporting the problem!

.. _`@lemieuxl`: https://github.com/PGScatalog/pgsc_calc/issues/75

pgsc_calc v1.3.0 (2022-11-21)
-----------------------------

This release is focused on improving scalability.

Features
~~~~~~~~

- Variant matching is made more efficient using a split - apply - combine
  approach when the data is split across chromosomes. This supports parallel PGS
  calculation for the largest traits (e.g. cancer, 418 PGS [avg 261,000
  variants/score) ) in the PGS Catalog on big datasets such as UK Biobank.

- Better support for running in offline environments:

  - Internet access is only required to download scores by ID. Scores can be
    pre-downloaded using the utils package
    (https://pypi.org/project/pgscatalog-utils/)

  - Scoring file metadata is read from headers and displayed in the report
    (removed API calls during report generation)

- Implemented flag (--efo_direct) to return only PGS tagged with exact EFO term
  (e.g. no PGS for child/descendant terms in the ontology)

pgsc_calc v1.2.0 (2022-10-11)
-----------------------------

This release is focused on improving memory and storage usage.

Features
~~~~~~~~

- Allow genotype dosages to be imported from VCF to be specified in ``vcf_genotype_field``
  of samplesheet_ (default: GT / hard calls)

- Makes use of `durable caching`_ when relabelling and recoding target genomes (``--genotypes_cache``)

- Improvements to use less storage space:

  - All intermediate files are now compressed by default

  - Add parameter to support zstd compressed input files

- Improved memory usage when matching variants (``pgscatalog_utils=v0.1.2``
  https://github.com/PGScatalog/pgscatalog_utils)

- Revised interface to select scores from the PGS Catalog using flags:
  ``--trait_efo`` (EFO ID / traits), ``--pgp_id`` (PGP ID / publications), ``--pgs_id`` (PGS ID, individual scores).

.. _samplesheet: https://pgsc-calc.readthedocs.io/en/dev/reference/input.html
.. _durable caching: https://pgsc-calc.readthedocs.io/en/dev/reference/params.html#parameter-schema

pgsc_calc v1.1.0 (2022-09-15)
-----------------------------

The first public release of the pgsc_calc pipeline. This release adds compatibility
for every score published in the PGS Catalog. Each scoring file in the PGS Catalog
has been processed to provide consistent genomic coordinates in builds GRCh37 and GRCh38.
The pipeline has been updated to take advantage of the harmonised scoring files (see
`PGS Catalog downloads`_ for additional details).

.. _PGS Catalog downloads: https://www.pgscatalog.org/downloads/#dl_ftp_scoring_hm_pos

Features
~~~~~~~~

- Many of the underlying software tools are now implemented within a ``pgscatalog_utils``
  package (``v0.1.2``, https://github.com/PGScatalog/pgscatalog_utils and
  https://pypi.org/project/pgscatalog-utils/ ). The packaging allows for independent
  testing and development of tools for downloading and working with the scoring files.

- The output report has been improved to have more detailed metadata describing
  the scoring files and how well the variants match the target sampleset(s).

- Improvements to variant matching:
    - More precise control of variant matching parameters is now possible, like
      ignoring strand flips
    - ``match_variants`` should now use less RAM by default:
        - A laptop with 16GB of RAM should be able to comfortably calculate scores on
          the 1000 genomes dataset
        - Fast matching mode (``--fast_match``) is available if ~32GB of RAM is
          available and you'd like to calculate scores for larger datasets

- Groups of scores from the PGS Catalog can be calculated by specifying a specific
  ``--trait`` (EFO ID) or ``--publication`` (PGP ID), in addition to using individual
  scoring files ``--pgs_id`` (PGS ID).

- Score validation has been integrated with the test suite

- Support for M1 Macs with ``--platform`` parameter (docker executor only)


Bug fixes
~~~~~~~~~

- Implemented a more robust prioritisation procedure if a variant has multiple
  candidate matches or duplicated IDs

- Fixed processing multiple samplesets in parallel (e.g. 1000 Genomes + UK
  Biobank)

- When combining multiple scoring files, all variants are now kept to reflect the
  correct denominator for % matching statistics.

- When trying to correct for strand flips the matched effect allele wasn't being
  correctly complemented

pgsc_calc v1.0.0 (2022-05-24)
--------------------------------

This release produces scores that should be biologically meaningful. Significant
effort has been made to validate calculate scores on different datasets. In the
next release we'll add score validation to our test suite to make sure
calculated scores stay valid in the future.

Features
~~~~~~~~

- Add support for PLINK2 format (samplesheet structure changed)
- Add support for allosomes (e.g. X, Y)
- Improve PGS Catalog compatibility (e.g. missing other allele)
- Add automatic liftover of scoring files to match target genome build
- Performance improvements to support UK BioBank scale data (500,000 genomes)
- Support calculation of multiple scores in parallel
- Significantly improved test coverage (> 80%)
- Lots of other small changes to improve correctness and handling edge cases

pgsc_calc v0.1.3dev (2022-02-04)
--------------------------------

Features
~~~~~~~~

- Simplified JSON input processes
- Add first draft of documentation
- Add JSON schemas for validating input data (mostly for web platform)

pgsc_calc v0.1.2dev (2022-01-17)
--------------------------------

Features
~~~~~~~~

- Add JSON input support for web platform functionality
- Set up simple CI tests with Github actions

pgsc_calc v0.1.1dev (2021-12-16)
--------------------------------

Features
~~~~~~~~

- First public release
- Support applying a single scoring file to target genomic data in GrCh37 build
