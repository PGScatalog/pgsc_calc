#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_BFILE } from '../../../../modules/local/plink2_bfile.nf'

workflow testbfile {
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
    def meta = [id: 'test']

    PLINK2_BFILE( Channel.of([meta, bed, bim, fam]) )
}
