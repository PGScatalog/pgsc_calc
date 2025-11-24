#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/pgscatalog/pgsc_calc
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { samplesheetToList; validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

include { PGSC_CALC  } from './workflows/pgsc_calc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow PGSCATALOG_PGSC_CALC {

    take:
    samplesheet // Channel: samplesheet read in from --input

    main:

    versions = Channel.empty()

    // validate parameters
    validateParameters()
    log.info paramsSummaryLog(workflow)

    // warn about the test profile
    if (workflow.profile.contains("test")) {
        log.info("The test profile is used to install the workflow and verify the software is working correctly on your system.")
        log.info("Test input data and results are are only useful as examples of outputs, and are not biologically meaningful.")
    }

    // be clear about liftover
    if (file(params.chain_files).baseName != "CHAIN_NO_FILE" & params.scorefile == null) {
        log.warn("Chain files are never needed for PGS Catalog scoring files")
        log.warn("Liftover is only useful for user-generated custom scoring files set by --scorefile")
        error("Remove --chain_files parameter unless you also set --scorefile")
    }

    // validate samplesheet
    ch_input = Channel.fromList(samplesheetToList(params.input, "assets/schema_input.json"))

    // check scorefiles are OK
    if (![params.scorefile, params.pgs_id, params.efo_id, params.pgp_id].any()) {
        error " ERROR: You didn't set any scores to use! Please set --scorefile, --pgs_id, --efo_id, or --pgp_id"
    }

    def joinParam = { p -> p?.tokenize(",")?.join(" ") ?: "" }
    pgscatalog_accessions = [
        pgs_id: joinParam(params.pgs_id),
        pgp_id: joinParam(params.pgp_id),
        efo_id: joinParam(params.efo_id)
    ]

    // publish the genotype cache zip?
    ch_publish_cache = Channel.value(params.publish_cache)
    // a singleton value channel (reused by all loading processes)
    ch_cache = Channel.value(file(params.genotype_cache_zip, checkIfExists: true))

    //
    // WORKFLOW: Run pipeline
    //
    PGSC_CALC (
        ch_input,
        params.target_build,
        pgscatalog_accessions,
        params.scorefile,
        file(params.chain_files),
        ch_cache,
        ch_publish_cache,
        versions
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // WORKFLOW: Run main workflow
    //
    PGSCATALOG_PGSC_CALC (
        params.input
    )
}

workflow.onComplete {
    if (workflow.success) {
        log.info "- [pgscatalog/pgsc_calc] Pipeline completed successfully -"
    }
}

workflow.onError {
    log.error "Pipeline failed. Please refer to troubleshooting docs: https://pgsc-calc.readthedocs.io/en/v3-rc1/"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
