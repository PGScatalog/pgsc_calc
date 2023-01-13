include { MATCH_VARIANTS     } from '../../modules/local/match_variants'
include { MATCH_COMBINE      } from '../../modules/local/match_combine'

workflow MATCH {
    take:
    geno
    pheno
    variants
    scorefile
    intersection

    main:
    ch_versions = Channel.empty()

    // TODO: add intersection
    variants
        .combine( scorefile )
        .dump(tag: 'match_variants_input')
        .set { ch_variants }

    MATCH_VARIANTS ( ch_variants )

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
        .dump(tag: 'match_variants_output')
        .set { matches }

    MATCH_COMBINE ( matches )
    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    emit:
    scorefiles = MATCH_COMBINE.out.scorefile
    db         = MATCH_COMBINE.out.summary
    versions   = ch_versions
}
