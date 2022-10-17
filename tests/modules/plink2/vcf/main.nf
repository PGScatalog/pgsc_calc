#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_VCF } from '../../../../modules/local/plink2_vcf'

workflow testvcf {
    vcf = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.vcf.gz')
    def meta = [id: 'test', is_vcf: true]

    PLINK2_VCF(Channel.of([meta, vcf]))

}
