:orphan:

Changelog
---------

Versions follow `semantic versioning`_ (``major.minor.patch``). Breaking changes
will only occur in major versions with changes noted in this changelog.

.. _`semantic versioning`: https://semver.org/

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
