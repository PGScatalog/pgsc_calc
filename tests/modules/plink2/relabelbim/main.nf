#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_RELABELBIM } from '../../../../modules/local/plink2_relabelbim'

workflow testrelabelbim {
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
    def meta = [id: 'test', build: 'GRCh37', is_bfile: true, chrom: 22]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )
}
