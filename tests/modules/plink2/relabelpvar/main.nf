#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_VCF }         from '../../../../modules/local/plink2_vcf'
include { PLINK2_RELABELPVAR } from '../../../../modules/local/plink2_relabelpvar'

workflow testrelabelpvar {
    vcf = file('assets/examples/target_genomes/cineca_synthetic_subset.vcf.gz')
    def meta = [id: 'test', 'build': 'GRCh37', chrom: 22]

    PLINK2_VCF(Channel.of([meta, vcf]))

    PLINK2_VCF.out.pgen.mix(PLINK2_VCF.out.psam, PLINK2_VCF.out.pvar)
        .groupTuple(size: 3, sort: true)
        .map { it.flatten() }
        .set { pfile }

    PLINK2_RELABELPVAR( pfile  )
}
