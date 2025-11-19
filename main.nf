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
include { samplesheetToList; validateParameters } from 'plugin/nf-schema'

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
    samplesheet // channel: samplesheet read in from --input

    main:

    versions = channel.empty()

    // validate parameters
    validateParameters()

    // warn about the test profile
    if (workflow.profile.contains("test")) {
        log.info("The test profile is used to install the workflow and verify the software is working correctly on your system.")
        log.info("Test input data and results are are only useful as examples of outputs, and are not biologically meaningful.")
    }

    // validate samplesheet
    ch_input = channel.fromList(samplesheetToList(params.input, "assets/schema_input.json"))

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

    //
    // WORKFLOW: Run pipeline
    //
    PGSC_CALC (
        ch_input,
        params.target_build,
        pgscatalog_accessions,
        params.scorefile,
        file(params.chain_files),
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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
