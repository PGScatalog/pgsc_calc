//
// Apply a validated scoring file to the QC'd target genomic data
//

include { PLINK2_SCORE } from '../../modules/local/plink2_score' addParams ( options: [:] )
include { COMBINE_SCORES } from '../../modules/local/combine_scores'
include { MAKE_REPORT    } from '../../modules/local/make_report'

workflow APPLY_SCORE {
    take:
    pgen // [[id: 1, is_vcf: true, chrom: 21], path(pgen)]
    psam // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    pvar // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    scorefile // [[id: 1, accession:PGS001229, chrom:21], path(scorefile)]

    main:
    ch_versions = Channel.empty()

    psam.map {
        n = -1 // exclude header from sample count
        it[1].eachLine { n++ }
        return tuple(it[0], n)
    }
        .set { n_samples }

    pgen
        .mix(psam, pvar)
        .groupTuple(size: 3, sort: true) // alphabetical  pgen, psam, pvar is nice
        .cross ( scorefile ) { [it.first().id, it.first().chrom] }
        .map{ it.flatten() }  // [[meta], pgen, psam, pvar, [scoremeta], scorefile]
        .join(n_samples, by: 0)
        .set { ch_apply } // data to apply scores to

    PLINK2_SCORE (
        ch_apply
    )

    ch_versions = ch_versions.mix(PLINK2_SCORE.out.versions)

    PLINK2_SCORE.out.score
        // TODO: size may vary per sample, make sure groupTuple has size:
        // https://github.com/nextflow-io/nextflow/issues/796
        // otherwise it will be much slower
        .map { [it.head().take(1), it.tail() ] }  // group just by ID TODO: check tail()
        .groupTuple()
        .map { [it.head(), it.tail().flatten()] } // [[meta], [path1, pathn]]
        .branch {
            split: (it.flatten().size() > 2)
            splat: (it.flatten().size() == 2)
        }
        .set { scores }

    COMBINE_SCORES (
        scores.split // only combine separate scores
    )

    ch_versions = ch_versions.mix(COMBINE_SCORES.out.versions.first())

    COMBINE_SCORES.out.scorefiles
        .mix(scores.splat)
        .set{ combined_scores }

    MAKE_REPORT(
        combined_scores,
        Channel.fromPath("$projectDir/bin/report.Rmd", checkIfExists: true),
        Channel.fromPath("$projectDir/assets/PGS_Logo.png", checkIfExists: true)
    )

    ch_versions = ch_versions.mix(MAKE_REPORT.out.versions)

    emit:
    score = combined_scores
    versions = ch_versions
}
