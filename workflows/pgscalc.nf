/*
========================================================================================
    VALIDATE INPUTS (SAMPLESHEET)
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPgscalc.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [params.input]

for (param in checkPathParamList) {
    file(param, checkIfExists: true)
}

// Check mandatory parameters
ch_input = file(params.input, checkIfExists: true)

// Set up scorefile channels ---------------------------------------------------
// scorefile accessions MUST be unique: they're used as keys for combining
// multiple scorefiles
Channel.fromPath(params.scorefile)
    .map { [[accession: it.getBaseName()], it ] }
    .set { scorefiles }

scorefiles
    .map { it.take(1) }
    .unique()
    .join(scorefiles)
    .set { unique_scorefiles }

Channel.fromList(params.accession?.tokenize(','))
    .unique() // tokenize to ensure unique
    .collect()
    .map { it.join(',') } // join again for calling API
    .set { unique_accessions }

// Don't check existence of optional parameters
allelic_freq = file(params.allelic_freq)

def run_input_check     = true
def run_make_compatible = true
def run_apply_score     = true

if (params.only_input) {
    run_input_check = true
    run_make_compatible = false
    run_apply_score = false
}

if (params.only_compatible) {
    run_input_check = true
    run_make_compatible = true
    run_apply_score = false
}

if (params.only_score) {
    run_input_check = true
    run_make_compatible = true
    run_apply_score = true
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { PGSCATALOG_GET       } from '../modules/local/pgscatalog_get'

include { INPUT_CHECK          } from '../subworkflows/local/input_check'
include { MAKE_COMPATIBLE      } from '../subworkflows/local/make_compatible'
include { APPLY_SCORE          } from '../subworkflows/local/apply_score'
include { DUMPSOFTWAREVERSIONS } from '../modules/local/dumpsoftwareversions'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PGSCALC {
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Get scoring file from PGS Catalog accession
    //
    if (params.accession) {
        PGSCATALOG_GET ( unique_accessions )
        scorefiles = unique_scorefiles.mix(PGSCATALOG_GET.out.scorefiles)
    } else {
        scorefiles = unique_scorefiles
    }

    scorefiles.map { it[1] }.collect().set{ ch_scorefile }

    //
    // SUBWORKFLOW: Validate and stage input files
    //

    if (run_input_check) {
        INPUT_CHECK (
            ch_input,
            params.format,
            ch_scorefile
        )
        ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    }

    //
    // SUBWORKFLOW: Make scoring file and target genomic data compatible
    //

    if (run_make_compatible) {
        MAKE_COMPATIBLE (
            INPUT_CHECK.out.bed,
            INPUT_CHECK.out.bim,
            INPUT_CHECK.out.fam,
            INPUT_CHECK.out.vcf,
            INPUT_CHECK.out.scorefiles
        )
        ch_versions = ch_versions.mix(MAKE_COMPATIBLE.out.versions)
    }

    //
    // SUBWORKFLOW: Apply a scoring file to target genomic data
    //

    if (run_apply_score) {
        APPLY_SCORE (
            MAKE_COMPATIBLE.out.pgen,
            MAKE_COMPATIBLE.out.psam,
            MAKE_COMPATIBLE.out.pvar,
            MAKE_COMPATIBLE.out.scorefile,
            allelic_freq,
            MAKE_COMPATIBLE.out.db
        )
        ch_versions = ch_versions.mix(APPLY_SCORE.out.versions)
    }

    //
    // MODULE: Dump software versions for all tools used in the workflow
    //
    DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
========================================================================================
    THE END
========================================================================================
*/
