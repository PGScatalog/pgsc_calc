.. _ancestry:

How do I normalise calculated scores across different genetic ancestry groups?
==============================================================================

Download reference data
-----------------------

The fastest method of getting started is to download our reference panel:

https://ftp.ebi.ac.uk/pub/databases/spot/pgs/resources/pgsc_calc.tar.zst

The reference panel is based on 1000 Genomes. It was originally downloaded from
the PLINK 2 resources section. To minimise file size INFO annotations are
excluded. KING pedigree corrections were enabled.

https://www.cog-genomics.org/plink/2.0/resources

Bootstrap reference data
~~~~~~~~~~~~~~~~~~~~~~~~

It's possible to bootstrap the reference data from the PLINK 2 data, which is
how we create the reference panel tar.

Custom reference support
~~~~~~~~~~~~~~~~~~~~~~~~

Custom reference support is planned for a future release.

Enable genetic similarity analysis and score normalisation
----------------------------------------------------------

