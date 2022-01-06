/*
========================================================================================
    VALIDATE INPUTS (SAMPLESHEET)
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPgscalc.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [params.input, params.scorefile]

if (params.input && params.json) {
    exit 1, 'Samplesheet input and JSON input are mutually exclusive'
}

for (param in checkPathParamList) {
    if (param && !params.json) {
        file(param, checkIfExists: true)
    }
}

// Check mandatory parameters
if (!params.json && params.input) {
    ch_input = file(params.input, checkIfExists: true)
    ch_json = Channel.empty()
} else {
    ch_input = Channel.empty()
    ch_json = Channel.from(params.json)
}

// Set up score channels
if (!params.accession && params.scorefile) {
    scorefile = Channel.of([[accession: file(params.scorefile).getName()], file(params.scorefile, checkIfExists: true)])
    accession = Channel.empty()
} else if (params.accession && !params.scorefile) {
    accession = params.accession
    scorefile = Channel.empty()
} else {
    exit 1, 'Please specify only one of --accession or --scorefile'
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { PGSCATALOG           } from '../subworkflows/local/pgscatalog'
include { INPUT_CHECK          } from '../subworkflows/local/input_check'
include { JSON_CHECK           } from '../subworkflows/local/json_check'
include { MAKE_COMPATIBLE      } from '../subworkflows/local/make_compatible'
include { SPLIT_GENOMIC        } from '../subworkflows/local/split_genomic'
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
    PGSCATALOG (
        accession
    )

    scorefile
        .mix( PGSCATALOG.out.scorefile )
        .set{ ch_scorefile }

    //
    // SUBWORKFLOW: Validate and stage input files
    //
    INPUT_CHECK (
        ch_input,
        ch_scorefile
    )

    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Validate and stage input files
    //
    JSON_CHECK (
        ch_json
    )

    ch_versions = ch_versions.mix(JSON_CHECK.out.versions)

    // now mix json input with samplesheet input
    INPUT_CHECK.out.bed
        .mix(JSON_CHECK.out.bed)
        .set{ ch_bed }

    INPUT_CHECK.out.bim
        .mix(JSON_CHECK.out.bim)
        .set{ ch_bim }

    INPUT_CHECK.out.fam
        .mix(JSON_CHECK.out.fam)
        .set{ ch_fam }

    //
    // SUBWORKFLOW: Split genetic data to improve parallelisation --------------
    //

    SPLIT_GENOMIC (
        ch_bed,
        ch_bim,
        ch_fam,
        INPUT_CHECK.out.scorefile
    )

    ch_versions = ch_versions.mix(SPLIT_GENOMIC.out.versions)

    //
    // SUBWORKFLOW: Make scoring file and target genomic data compatible
    //
    MAKE_COMPATIBLE (
        SPLIT_GENOMIC.out.bed,
        SPLIT_GENOMIC.out.bim,
        SPLIT_GENOMIC.out.fam,
        SPLIT_GENOMIC.out.scorefile
    )

    ch_versions = ch_versions.mix(MAKE_COMPATIBLE.out.versions)

    //
    // SUBWORKFLOW: Apply a scoring file to target genomic data
    //
    APPLY_SCORE (
        MAKE_COMPATIBLE.out.pgen,
        MAKE_COMPATIBLE.out.psam,
        MAKE_COMPATIBLE.out.pvar,
        MAKE_COMPATIBLE.out.scorefile
    )

    ch_versions = ch_versions.mix(APPLY_SCORE.out.versions)

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
