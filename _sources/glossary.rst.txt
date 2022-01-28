Glossary
========

.. glossary::
     accession
         A unique and stable identifier

     polygenic score
         A `polygenic score`_ (PGS) aggregates the effects of many genetic variants
         into a single number which predicts genetic predisposition for a
         phenotype. PGS are typically composed of hundreds-to-millions of genetic
         variants (usually SNPs) which are combined using a weighted sum of allele
         dosages multiplied by their corresponding effect sizes, as estimated from
         a relevant genome-wide association study (GWAS).

         .. _polygenic score: https://www.pgscatalog.org/about/

     PGS Catalog
         The `PGS Catalog`_ is an open database of published polygenic scores
         (PGS). If you develop and publish polygenic scores, please consider
         `submitting them`_ to the Catalog!

         .. _PGS Catalog: https://www.pgscatalog.org
         .. _submitting them: https://www.pgscatalog.org/submit/

     PGS Catalog Calculator
         This cool workflow

     Scoring file
         A file for scoring

     SNP
         A single nucleotide polymorphism

     driver pod
     pod
         `A pod`_ is a description of one or more containers and its associated
         computing resources (e.g. number of processes and RAM, but it's more
         complicated than that). Kubernetes takes this description and tries to
         make it exist on the cluster. The driver pod is responsible for managing
         a workflow instance. The driver pod will monitor and submit each job in
         the workflow as a separate worker pod.

         .. _A pod: https://kubernetes.io/docs/concepts/workloads/pods/

     worker pods
         Pods unite! You have nothing to lose but your chains.
