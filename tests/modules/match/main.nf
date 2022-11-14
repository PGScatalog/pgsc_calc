#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { COMBINE_SCOREFILES } from '../../../modules/local/combine_scorefiles.nf'
include { PLINK2_RELABELBIM } from '../../../modules/local/plink2_relabelbim'
include { MATCH_VARIANTS } from '../../../modules/local/match_variants'
include { MATCH_COMBINE }  from '../../../modules/local/match_combine'

workflow testmatch {
    // test a single score (one effect weight)
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
    scorefile = Channel.fromPath('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/PGS001229_22.txt')

    Channel.fromPath(params.ref, checkIfExists: true)
        .set { ch_reference }

    COMBINE_SCOREFILES ( scorefile, ch_reference )

    ch_scorefiles = COMBINE_SCOREFILES.out.scorefiles

    def meta = [id: 'test', is_bfile: true, n_samples: 100, n_chrom: 1, chrom: 'ALL']
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    ch_variants = PLINK2_RELABELBIM.out.variants

    ch_variants.combine( ch_scorefiles )
        .set { ch_match_input }

    ch_match_input.view()
    MATCH_VARIANTS( ch_match_input )

    emit:
    scorefile = ch_scorefiles
    matches = MATCH_VARIANTS.out.matches

}

workflow testmatchcombine {
    testmatch()
    ch_combine = testmatch.out.matches.combine(testmatch.out.scorefile)
    MATCH_COMBINE(ch_combine)
}
