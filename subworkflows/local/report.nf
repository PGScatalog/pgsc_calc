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
    intersect_count

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

    // ch_scores keeps calculated score file names consistent with --skip_ancestry
    ch_scores = Channel.empty()
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
        ancestry_results = ancestry_results.mix(
            ANCESTRY_ANALYSIS.out.info,
            ANCESTRY_ANALYSIS.out.popsimilarity)
            .map { annotate_sampleset(it) }
            .groupTuple(size: 2)

        // ancestry_analysis: aggregated_scores.txt.gz -> {sampleset}_pgs.txt.gz
        ch_scores = ch_scores.mix(ANCESTRY_ANALYSIS.out.pgs.map{annotate_sampleset(it)})
        ch_versions = ch_versions.mix(ANCESTRY_ANALYSIS.out.versions)
    } else {
        // score_aggregate (no ancestry) -> aggregated_scores.txt.gz
        ch_scores = ch_scores.mix(scores)

        // make NO_FILE for each sampleset to join correctly later
        ancestry_results = ancestry_results.mix(
            ch_scores.map {it[0]} // unique samplesets
                .combine(Channel.fromPath('NO_FILE'))
        )
    }

    // prepare report input channels -------------------------------------------
    log_match.map { annotate_sampleset(it) }
        .set { ch_annotated_log }

    ch_scores
        .join(ch_annotated_log, by: 0)
        .join(ancestry_results, by: 0)
        .combine(log_scorefiles) // all samplesets have the same scorefile metadata
        .set { ch_report_input }

    SCORE_REPORT( ch_report_input, intersect_count )
    ch_versions = ch_versions.mix(SCORE_REPORT.out.versions)

    // if this workflow runs, the report must be written
    report_fail = true
    SCORE_REPORT.out.report.subscribe onNext: { report_fail = false },
        onComplete: { report_error(report_fail) }

    emit:
    versions = ch_versions
}

def annotate_sampleset(it) {
    [['id': it.getName().tokenize('_')[0]], it]
}

def report_error(boolean fail) {
    if (fail) {
        log.error "ERROR: No results report written!"
        System.exit(1)
    }
}
