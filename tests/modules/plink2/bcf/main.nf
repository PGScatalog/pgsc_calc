#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_VCF } from '../../../../modules/local/plink2_vcf'

workflow testbcf {

    bcf = file('assets/examples/target_genomes/cineca_synthetic_subset.bcf', checkIfExists: true)
    def meta = [id: 'test', is_vcf: true, is_bcf: true, build: 'GRCh37', chrom: '22',
                vcf_import_dosage: false, is_bfile: false, is_pfile: false]

    PLINK2_VCF(Channel.of([meta, bcf]))

}
