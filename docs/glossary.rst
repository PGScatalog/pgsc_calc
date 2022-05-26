Glossary
========

.. glossary::

     CSV
         Comma-separated values, a popular plain text file format. `CSVs are
         good`_. Please don't use ``.xlsx`` (Excel), it makes bioinformaticians
         sad.

     JSON
         Javascript Object Notation. A popular file format and data interchange
         format.

     PGS Catalog
         The `PGS Catalog`_ is an open database of published polygenic scores
         (PGS). If you develop and publish polygenic scores, please consider
         `submitting them`_ to the Catalog!

     PGS Catalog Calculator
         ``pgsc_calc`` -  this cool workflow!

     SNP
         A `single nucleotide polymorphism`_

     Scoring file
         A file containing risk alleles and derived weights for a specific
         phenotype. Weights are typically calculated with 1) GWAS summary
         statistics and 2) A large population of people with known phenotypes
         (e.g. the `UK BioBank`_). These files are hopefully published in the
         PGS Catalog.

     VCF
         Variant Call Format. A popular `standard file format`_ used to store
         genetic variants.

     accession
         A unique and stable identifier. PGS Catalog accessions start with the
         prefix PGS, e.g. `PGS000001`_

     driver pod
     pod
         `A pod`_ is a description of one or more containers and its associated
         computing resources (e.g. number of processes and RAM, but it's more
         complicated than that). Kubernetes takes this description and tries to
         make it exist on the cluster. The driver pod is responsible for managing
         a workflow instance. The driver pod will monitor and submit each job in
         the workflow as a separate worker pod.

     polygenic score
         A `polygenic score`_ (PGS) aggregates the effects of many genetic variants
         into a single number which predicts genetic predisposition for a
         phenotype. PGS are typically composed of hundreds-to-millions of genetic
         variants (usually SNPs) which are combined using a weighted sum of allele
         dosages multiplied by their corresponding effect sizes, as estimated from
         a relevant genome-wide association study (GWAS).

     target genomic data
         Genomes that you want to calculate polygenic scores for. Scores are
         calculated from an existing scoring file that contains risk alleles and
         associated weights. These genomes are distinct from those used to
         create the polygenic scoring file originally (i.e., those used to
         derive the risk alleles and weights).

     worker pods
         A pod, managed by the nextflow driver pod, that is responsible for
         executing an atomic process in the workflow. They are created and
         destroyed automatically by the driver pod.

.. _CSVs are good: https://www.gov.uk/guidance/using-csv-file-format
.. _A pod: https://kubernetes.io/docs/concepts/workloads/pods/
.. _single nucleotide polymorphism: https://en.wikipedia.org/wiki/Single-nucleotide_polymorphism
.. _UK BioBank: https://www.ukbiobank.ac.uk/    
.. _PGS Catalog: https://www.pgscatalog.org
.. _submitting them: https://www.pgscatalog.org/submit/
.. _PGS000001: https://www.pgscatalog.org/score/PGS000001/
.. _standard file format: https://samtools.github.io/hts-specs/VCFv4.2.pdf
.. _polygenic score: https://www.pgscatalog.org/about/
