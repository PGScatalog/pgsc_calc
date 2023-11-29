.. _database:

How do I set up the reference database?
=======================================

A reference database is required to run some parts of the workflow:

- Automatic genetic ancestry assignment with Principal Component Analysis
- PGS normalisation methods that account for genetic ancestry

.. note:: It's simplest to download a reference database we host at the
          PGS Catalog FTP

Download reference database
---------------------------

PGS Catalog created reference database(s) are available to download here:

``https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_1000G_v1.tar.zst``
``https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_HGDP+1kGP_v1.tar.zst``

The databases are either 7GB or 16GB and support both GRCh37 and GRCh38 input target
genomes.

Once the reference database is included, remember you must include the ``--run_ancestry``
parameter, which is a path to the reference database (see
:ref:`schema`).

(Optional) Create reference database
------------------------------------

.. Warning::
   - Making a reference database from scratch can be slow and frustrating
   - It's easiest to download the published reference database from the PGS Catalog FTP
            
You can choose to create the reference database from scratch. The default
reference database uses genomes from the 1000 Genomes project.

1. Download the :download:`reference sample sheet
   <../../assets/ancestry/reference.csv>`
2. Update the URL column to point to the most recent URLs listed on the plink 2
   `resources page`_. These URLs change over time.

   .. note:: You can also set the URL column to a local file path if you've already downloaded the files.

   - Mandatory files include:

     - The compressed binary genotype file (``pgen.zst``)
     - The compressed unannotated variant information file (``pvar.zst``)
     - The sample information file (``psam``)
     - The pedigree information file (``king``)


3. Run the workflow with the ``--ref_samplesheet`` parameter, which is mutually
   exclusive with the ``--ref`` parameter (see :ref:`schema`).

.. note:: This approach could be used to create a custom reference
          database. For example, including genomes from the Human Genome
          Diversity Project. Please `talk to us`_ if you'd like to try this.

.. _`resources page`: https://www.cog-genomics.org/plink/2.0/resources
.. _`talk to us`: https://github.com/PGScatalog/pgsc_calc/discussions
