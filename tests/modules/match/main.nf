#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { COMBINE_SCOREFILES } from '../../../modules/local/combine_scorefiles.nf'
include { PLINK2_RELABELBIM } from '../../../modules/local/plink2_relabelbim'
include { MATCH_VARIANTS } from '../../../modules/local/match_variants'
include { MATCH_COMBINE }  from '../../../modules/local/match_combine'

workflow testmatch {
    // test a single score (one effect weight)
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = Channel.fromPath("assets/examples/scorefiles/PGS001229_22.txt", checkIfExists: true)

    Channel.fromPath('NO_FILE', checkIfExists: false).set { chain_files }

    COMBINE_SCOREFILES ( scorefile, chain_files )

    ch_scorefiles = COMBINE_SCOREFILES.out.scorefiles

    def meta = [id: 'test', is_bfile: true, n_samples: 100, n_chrom: 1, chrom: 'ALL']
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    ch_variants = PLINK2_RELABELBIM.out.variants

    ch_variants.combine( ch_scorefiles )
        .set { ch_match_input }

    MATCH_VARIANTS( ch_match_input )

    emit:
    scorefile = ch_scorefiles
    matches = MATCH_VARIANTS.out.matches

}

workflow testmatchcombine {
    // match combine can be optionally constrained by a list of variants in a
    // reference panel (don't test this here)
    ref_intersection = Channel.of(file('NO_FILE'))

    testmatch()

    testmatch.out.matches
        .map{ [ it[0], it.tail().flatten() ] }
        .combine( testmatch.out.scorefile )
        .combine( ref_intersection )
        .set { ch_combine }

    ch_combine.view()
    MATCH_COMBINE( ch_combine.combine(ref_intersection) )
}
