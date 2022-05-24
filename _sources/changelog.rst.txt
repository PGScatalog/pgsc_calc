:orphan:
   
Changelog
---------

Versions follow `semantic versioning`_ (``major.minor.patch``). Breaking changes
will only occur in major versions with changes noted in this changelog.

.. _`semantic versioning`: https://semver.org/


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
