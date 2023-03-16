include { ANCESTRY_ANALYSIS } from '../../modules/local/ancestry/ancestry_analysis'
include { SCORE_REPORT } from '../../modules/local/score_report'

workflow REPORT {
    take:
    ref_pheno
    ref_relatedness
    scores
    projections
    log_scorefiles
    log_match
    run_ancestry_assign // bool

    main:
    ch_versions = Channel.empty()
    ancestry_results = Channel.empty()

    /*
     - typically channels contain one element per sampleset or chromosome
     - this subworkflow handles things a little differently
     - at this stage some process inputs will be aggregated (e.g. scores)
     - and some data still needs to be aggregated (e.g. principal components)
     - so the channel input to ANCESTRY_ANALYSIS and SCORE_REPORT
       should have one element, which is a tuple of paths
     - in this tuple, unaggregated data are stored as lists of paths
     - aggregated data are standard paths
     - lists of paths get staged to processes with generated names to prevent
       file input collisions
     */
    if (run_ancestry_assign) {

        scores
            .combine(ref_relatedness)
            .combine(ref_pheno)
            .flatten()
            .filter{ !(it instanceof LinkedHashMap) }
            .buffer(size: 3)
            .set{ ch_scores_and_pop }

        projections
            .combine( ch_scores_and_pop )
            .set { ch_ancestry_input }

        ANCESTRY_ANALYSIS ( ch_ancestry_input )
        ancestry_results = ANCESTRY_ANALYSIS.out.results
        ch_versions = ch_versions.mix(ANCESTRY_ANALYSIS.out.versions)
    } else {
        ancestry_results = ancestry_results.mix(Channel.of('NO_FILE'))
    }

    SCORE_REPORT(
        scores,
        log_scorefiles,
        Channel.fromPath("$projectDir/bin/report.Rmd", checkIfExists: true),
        Channel.fromPath("$projectDir/assets/PGS_Logo.png", checkIfExists: true),
        log_match.collect(),
        ancestry_results
    )
    ch_versions = ch_versions.mix(SCORE_REPORT.out.versions)

    emit:
    versions = ch_versions
}
