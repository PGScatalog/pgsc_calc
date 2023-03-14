include { ANCESTRY_ANALYSIS } from '../../modules/local/ancestry/ancestry_analysis'
include { SCORE_REPORT } from '../../modules/local/score_report'

workflow REPORT {
    take:
    ref_pheno
    ref_relatedness
    scores
    pcs
    log_scorefiles
    log_match
    vars_projected
    vars_scored

    main:
    ch_versions = Channel.empty()

    // TODO: set up ancestry analysis channel
    // ANCESTRY_ANALYSIS ( pcs, vars_projected, scores, vars_scored )

    SCORE_REPORT(
        scores,
        log_scorefiles,
        Channel.fromPath("$projectDir/bin/report.Rmd", checkIfExists: true),
        Channel.fromPath("$projectDir/assets/PGS_Logo.png", checkIfExists: true),
        log_match.collect()
    )
    ch_versions = ch_versions.mix(SCORE_REPORT.out.versions)

    emit:
    versions = ch_versions
}
