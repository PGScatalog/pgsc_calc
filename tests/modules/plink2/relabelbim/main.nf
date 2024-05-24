#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_RELABELBIM } from '../../../../modules/local/plink2_relabelbim'

workflow testrelabelbim {
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    def meta = [id: 'test', build: 'GRCh37', is_bfile: true, chrom: 22]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )
}
