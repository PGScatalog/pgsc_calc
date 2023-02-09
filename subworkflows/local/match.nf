include { MATCH_VARIANTS } from '../../modules/local/match_variants'
include { MATCH_COMBINE  } from '../../modules/local/match_combine'

workflow MATCH {
    take:
    geno
    pheno
    variants
    scorefile
    ch_intersection

    main:
    ch_versions = Channel.empty()

    variants
        .combine(scorefile)
        .dump(tag: 'match_variants_input')
        .set { ch_variants }

    MATCH_VARIANTS ( ch_variants )
    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    // create custom groupKey() to set a different group size for each
    // sampleset.  different samplesets may have different numbers of
    // chromosomes. so if a groupKey size is not provided then nextflow must
    // wait for the entire process to finish before releasing the grouped
    // tuples. setting a groupKey size avoids lots of unnecessary waiting.
    MATCH_VARIANTS.out.matches.map{
        tuple(groupKey(it[0].subMap(['id', 'is_vcf', 'is_bfile', 'is_pfile']),
                       it[0].n_chrom),
              it[0].chrom,
              it[1])
    }
        .groupTuple()
        .combine( scorefile )
        .set { ch_matches }

    ch_intersection.map { tuple(groupKey(it[0].subMap(['id']),
                                         it[0].n_chrom),
                                it.last()) }
        .groupTuple()
        .set { ch_intersection_grouped }

    // ch_matches id _must be unique_ for .cross() (this is guaranteed after
    // groupTuple). this seems complicated but joining by key is the best way to
    // make sure the correct intersections match the sample sets. ensuring sort
    // order of two input channels would be more difficult.
    ch_matches
        // extract key
        .map{ [it[0]['id'], it] }
        .cross(ch_intersection_grouped.map{it -> [it[0]['id'], it]})
        // drops key and combine list elements
        .map { it[0].last() + it[1].last() }
        .set { ch_match_combine_input }
    // example channel structure is a list of:
    // meta map: [id:hgdp, is_vcf:false, is_bfile:false, is_pfile:true]
    // chrom list: [3, ..., 17],
    // match list: [hgdp_match_0.ipc.zst, ...]
    // scorefile path: scorefiles.txt.gz,
    // intersection meta: [id:hgdp]
    // optional intersection list of paths: [NO_FILE] / [matched_1.txt ... ]

    MATCH_COMBINE ( ch_match_combine_input )
    ch_versions = ch_versions.mix(MATCH_COMBINE.out.versions)

    // extra check to make sure subworkflow completed successfully
    def combine_fail = true
    MATCH_COMBINE.out.scorefile.subscribe onNext: { combine_fail = false },
        onComplete: { combine_error(combine_fail) }

    emit:
    scorefiles = MATCH_COMBINE.out.scorefile
    db         = MATCH_COMBINE.out.summary
    versions   = ch_versions
}

def combine_error(boolean fail) {
    if (fail) {
        log.error "ERROR: Final scorefile wasn't produced!"
        System.exit(1)
    }
}
