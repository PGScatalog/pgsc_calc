#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/pgscatalog/pgsc_calc
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsHelp; paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PGSCCALC } from './workflows/pgsc_calc'

//
// WORKFLOW: Run main pgscatalog/pgsccalc analysis pipeline
//
workflow PGSCATALOG_PGSCCALC {
    PGSCCALC ()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    main:
    if (params.help) {
        if (params.help.toString() == 'true') {
            log.info "Typical pipeline command:\n\n  nextflow run pgscatalog/pgsc_calc --input input_file.csv\n"
        } else {
            log.info paramsHelp([:], "nextflow run pgscatalog/pgsc_calc --input input_file.csv")
        }
        log.info "See https://pgsc-calc.readthedocs.io/en/latest/getting-started.html for more help"
        exit 0
    }

    WorkflowMain.initialise(workflow, params, log, args)

    logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
    citation = '\n' + WorkflowMain.citation(workflow) + '\n'

    // Print parameter summary log to screen
    log.info logo + paramsSummaryLog(workflow) + citation

    WorkflowPgscCalc.initialise(params, log)

    PGSCATALOG_PGSCCALC ()

    workflow_meta = workflow
    params_meta = params
    log_meta = log
    project_dir_meta = projectDir

    workflow.onComplete {
        def summary_params = paramsSummaryMap(workflow_meta)
        if (params_meta.email || params_meta.email_on_fail) {
            NfcoreTemplate.email(workflow_meta, params_meta, summary_params, project_dir_meta, log_meta)
        }
        NfcoreTemplate.dump_parameters(workflow_meta, params_meta)
        NfcoreTemplate.summary(workflow_meta, params_meta, log_meta)
        if (params_meta.hook_url) {
            NfcoreTemplate.IM_notification(workflow_meta, params_meta, summary_params, project_dir_meta, log_meta)
        }
    }

    workflow.onError {
        if (workflow_meta.errorReport?.contains("Process requirement exceeds available memory")) {
            println("🛑 Default resources exceed availability 🛑 ")
            println("💡 See here on how to configure pipeline: https://nf-co.re/docs/usage/configuration#tuning-workflow-resources 💡")
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
