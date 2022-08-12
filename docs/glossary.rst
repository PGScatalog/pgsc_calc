:orphan:
   
Glossary
========

.. glossary::

     accession
         A unique and stable PGS Catalog score identifier (ID). PGS Catalog IDs start
         with the prefix PGS, e.g. `PGS000001`_

     CSV
         Comma-separated values, a popular plain text file format. `CSVs are
         good`_. Please don't use ``.xlsx`` (Excel), it makes bioinformaticians
         sad.

     JSON
         Javascript Object Notation. A popular file format and data interchange
         format.

     polygenic score
         A `polygenic score`_ (PGS), aggregates the effects of many genetic variants
         into a single number which quantifies an individual's genetic predisposition
         for a phenotype. PGS are typically composed of hundreds-to-millions of genetic
         variants (usually SNPs) which are calculated as a weighted sum of allele
         dosages multiplied by their corresponding effect sizes. The variants and their effect sizes
         are most often derived from a genome-wide association study (GWAS) using many
         common software tools (including Pruning/Clumping + Thresholding (e.g. PRSice),
         LDpred, lassosum, snpnet).

     polygenic risk score
         A polygenic risk score (PRS) is a subset of PGS that is used to estimate the
         risk of disease or other clinically relevant outcomes (binary or discrete).
         Also sometimes referred to as a genetic or genomic risk score (GRS).

     PGS Catalog
         The `Polygenic Score (PGS) Catalog`_ is an open database of published polygenic
         scores (PGS). If you develop and publish polygenic scores, please consider
         `submitting them`_ to the Catalog so they can be reused and applied to new
         datasets using this pipeline!

     PGS Catalog Calculator
         ``pgsc_calc`` -  a reproducible workflow to calculate one or multiple PGS, implemented
         in `Nextflow`_.

     SNP
         A `single nucleotide polymorphism`_ - most PGS only contain this type of variant
         in addition to smaller common insertions/deletions (INDELS).

     Scoring file
         A file containing risk alleles and derived weights for a specific
         phenotype. Weights are typically calculated with 1) GWAS summary
         statistics and 2) A large population of people with known phenotypes
         (e.g. the `UK BioBank`_). These files are distributed through the
         PGS Catalog in a `standardized format`_, and also provided as
         `harmonized scoring files`_ with consistently-reported positions in
         common genome builds (GRCh37 and GRCh38). The pipeline

     target dataset
         The genomes/genotyping data that you want to calculate polygenic scores for.
         Scores are calculated from an existing scoring file that contains effect alleles
         and associated weights. These genomes should distinct from those used to
         develop the polygenic score originally (i.e., those used to derive the risk alleles
         and weights), as overlapping samples will inflate common metrics of PGS accuracy.

     VCF
         Variant Call Format. A `standard file format`_ used to store genetic variants and genotypes.

.. _CSVs are good: https://www.gov.uk/guidance/using-csv-file-format
.. _single nucleotide polymorphism: https://en.wikipedia.org/wiki/Single-nucleotide_polymorphism
.. _UK BioBank: https://www.ukbiobank.ac.uk/    
.. _PGS Catalog: https://www.pgscatalog.org
.. _submitting them: https://www.pgscatalog.org/submit/
.. _PGS000001: https://www.pgscatalog.org/score/PGS000001/
.. _standard file format: https://samtools.github.io/hts-specs/VCFv4.2.pdf
.. _polygenic score: https://www.pgscatalog.org/about/
.. _Nextflow: https://www.nextflow.io
.. _standardized format: https://www.pgscatalog.org/downloads/#dl_ftp_scoring
.. _harmonized scoring files: https://www.pgscatalog.org/downloads/#dl_ftp_scoring_hm_pos