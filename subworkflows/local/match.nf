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

    // convert to a nested list of length 1 [[scorefile1_path, scorefile2_path]]
    scorefiles = scorefile.collect { [it] }

    variants
        .combine(scorefiles)
        .dump(tag: 'match_variants_input', pretty: true)
        .set { ch_variants }

    MATCH_VARIANTS ( ch_variants )
    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions.first())

    // groupTuple() notes:
    // removed custom groupKeys because only one group will ever be processed
    // (1 sampleset limitation added for v2 release)
    // so groupTuple's size parameter isn't needed in this subworkflow

    // use multiMaps + concat to preserve lists of files after concatenating
    // joining or combining can create nested lists (annoying to handle)
    MATCH_VARIANTS.out.matches
        .multiMap {
            meta: it.first()
            matches: it.last()
        }
        .set { ch_matches }

    ch_intersection
        .groupTuple()
        .multiMap {
            meta: it.first()
            intersections: it.last()
        }
        .set { ch_intersection_grouped }

    // only meta.chrom is checked to see if it's set to 'ALL' or not
    // but using chrom values directly in meta map breaks cache because chrom order can differ across runs
    ch_matches.meta.first().map { it ->
        def split = it.chrom != "ALL"
        return [split:split, id: it.id]
    }.set { combine_meta }

    combine_meta
        .concat( ch_matches.matches.collect() )
        .concat( scorefile )
        .concat( ch_intersection_grouped.intersections.collect() )
        .buffer( size: 4 )
        .dump ( tag: 'match_combine_input', pretty: true )
        .set { ch_match_combine_input }

     MATCH_COMBINE ( ch_match_combine_input )
     ch_versions = ch_versions.mix(MATCH_COMBINE.out.versions)

    emit:
    scorefiles = MATCH_COMBINE.out.scorefile
    db         = MATCH_COMBINE.out.summary
    versions   = ch_versions
}
