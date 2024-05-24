#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_VCF } from '../../../../modules/local/plink2_vcf'

workflow testvcf {
    
    vcf = file('assets/examples/target_genomes/cineca_synthetic_subset.vcf.gz', checkIfExists: true)
    def meta = [id: 'test', is_vcf: true, build: 'GRCh37', chrom: '22']

    PLINK2_VCF(Channel.of([meta, vcf]))

}
