/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def valid_params = [
    format : ['vcf', 'bgen']
]

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPgscalc.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input
]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
// TODO: think about dummy meta val
if (params.input) { ch_input = [[ id:'test'], file(params.input)] } else { exit 1, 'Genotype input not specified!' }
if (params.format) { ch_format = params.format } else { exit 1, 'Input format not specified!' } 

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

//
// MODULE: Local to the pipeline
//
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions' addParams( options: [publish_files : ['tsv':'']] )

// TODO: do sample sheets make sense for a VCF?
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
// include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { PLINK_VCF } from '../modules/nf-core/modules/plink/vcf/main' addParams (options: modules['plink_vcf'] ) 

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PGSCALC {
    ch_software_versions = Channel.empty()

    // TODO: decide if we need a samplesheet
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    // INPUT_CHECK (
    //    ch_input
    // )

    //
    // MODULE: Run plink ingestion
    // TODO: modify to subworkflow to liftOver too?
    //

    // TODO: check dummy value
    //ch_input = Channel.from('input_genetic').concat(ch_input)
    
    PLINK_VCF (
        ch_input
    )
    
    ch_software_versions = ch_software_versions.mix(PLINK_VCF.out.versions)

    //
    // MODULE: Pipeline reporting
    //
    ch_software_versions
        .map { it -> if (it) [ it.baseName, it ] }
        .groupTuple()
        .map { it[1][0] }
        .flatten()
        .collect()
        .set { ch_software_versions }

    GET_SOFTWARE_VERSIONS (
        ch_software_versions.map { it }.collect()
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
