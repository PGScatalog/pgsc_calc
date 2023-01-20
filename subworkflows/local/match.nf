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

    // TODO: this doesn't work with multiple input chromosomes! :|
    // this is only needed to successfully join on the output of MATCH_VARIANTS.out.matches
    ch_intersection.map {
        tuple(it.first().subMap(['id', 'is_vcf', 'is_bfile', 'is_pfile']),
              it.tail())
    }
        .map { it.flatten() }
        .dump(tag:'intersected')
        .set { ch_flat_intersection }

    MATCH_VARIANTS.out.matches.map{
        tuple(groupKey(it[0].subMap(['id', 'is_vcf', 'is_bfile', 'is_pfile']),
                       it[0].n_chrom),
              it[0].chrom,
              it[1])
    }
        .groupTuple()
        .combine( scorefile )
        .dump(tag: 'tupled_variants_output')
        .join( ch_flat_intersection )
        .dump(tag: 'match_variants_output')
        .set { ch_matches }

    MATCH_COMBINE ( ch_matches )
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
