//
// Apply a validated scoring file to the QC'd target genomic data
//

include { PLINK2_SCORE } from '../../modules/local/plink2_score'
include { COMBINE_SCORES } from '../../modules/local/combine_scores'
include { MAKE_REPORT    } from '../../modules/local/make_report'

workflow APPLY_SCORE {
    take:
    pgen // [[id: 1, is_vcf: true, chrom: 21], path(pgen)]
    psam // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    pvar // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    scorefiles // [[id: 1, chrom:21], path(scorefiles)]

    main:
    ch_versions = Channel.empty()

    scorefiles
        .flatMap { annotate_scorefiles(it) }
        .set { annotated_scorefiles }

    psam.map {
        n = -1 // exclude header from sample count
        it[1].eachLine { n++ }
        return tuple(it[0], n)
    }
        .set { n_samples }

    // intersect genomic data with split scoring files -------------------------
    pgen
        .mix(psam, pvar)
        .groupTuple(size: 3, sort: true) // alphabetical  pgen, psam, pvar is nice
        .cross ( annotated_scorefiles ) { [it.first().id, it.first().chrom.toString()] }
        .map { it.flatten() }
        .join(n_samples, by: 0)
        .dump(tag: 'ready_to_score')
        .set { ch_apply }

    PLINK2_SCORE ( ch_apply )

    ch_versions = ch_versions.mix(PLINK2_SCORE.out.versions.first())

    PLINK2_SCORE.out.scores
        .collect()
        .set { ch_scores }

    MAKE_REPORT(
        ch_scores,
        Channel.fromPath("$projectDir/bin/report.Rmd", checkIfExists: true),
        Channel.fromPath("$projectDir/assets/PGS_Logo.png", checkIfExists: true)
    )

    ch_versions = ch_versions.mix(MAKE_REPORT.out.versions)

    emit:
    score = MAKE_REPORT.out.scores
    versions = ch_versions
}

// add chromosome to a scorefile's meta map
// [[meta], [scorefile_1, ..., scorefile_n]] -> flat list
def annotate_scorefiles(ArrayList scorefiles) {
    scorefiles.combinations()
        .collect {
            meta = it[0] // class: nextflow groupKey from custom groupTuple
            scorefile_path = it[1]
            def m = [:]
            m.id = meta.id
            m.chrom = scorefile_path.getName().tokenize('_')[0]
            return [m, scorefile_path]
        }
}
