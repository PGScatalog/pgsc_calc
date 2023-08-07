## Reference Datasets
Data in `reference.csv` are links to reference population genetic datasets distributed via the Plink 
resources page (https://www.cog-genomics.org/plink/2.0/resources). This currently includes:

- 1000 Genomes : A global reference for human genetic variation, *The 1000 Genomes Project Consortium*, 
  Nature 526, 68-74 (01 October 2015) doi:[10.1038/nature15393](https://doi.org/10.1038/nature15393).
    
## Exclusion Regions for PCA Analyses
These files (in bed format,=: [chr, start, end, name]) contain regions of high linkage disequilibrium (LD) 
that should be excluded from PCA:

- `flashpca_exclusion_regions_hg19.txt`
	- source: https://github.com/gabraham/flashpca
	- date downloaded : 08/12/2022
	
- `high-LD-regions-hg19-GRCh37.txt` , `high-LD-regions-hg38-GRCh38.txt`
	- source: https://github.com/cran/plinkQC/tree/master/inst/extdata and 
	  https://genome.sph.umich.edu/wiki/Regions_of_high_linkage_disequilibrium_(LD)#cite_note-3
	- date: 08/12/2022