include { MATCH_VARIANTS     } from '../../modules/local/match_variants'
include { MATCH_COMBINE      } from '../../modules/local/match_combine'

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

    // MATCH_COMBINE input note:
    // ch_intersection and ch_matches sampleset order should be the same
    // e.g.: ch_matches: [[id: cineca], chrom, [ipc0, ...], scorefile]
    // ch_intersection: [[id: cineca], matched.txt.gz]
    // normally there'd be a join to enforce sampleset order but things get
    // unpleasant with optional inputs. how can you join on file('NO_FILE')??
    // there's no meta key! do we do a fake meta key too?
    MATCH_COMBINE ( ch_matches, ch_intersection )
    ch_versions = ch_versions.mix(MATCH_COMBINE.out.versions)

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
