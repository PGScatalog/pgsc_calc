/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowPgscalc.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [
    params.input,
    params.scorefile
]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Genotype input not specified!' }
if (params.scorefile) { ch_scorefile = file(params.scorefile) } else { exit 1, 'Score file not specified!' }

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

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )
include { SPLIT } from '../subworkflows/local/split' addParams( options: [:] )

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

    // TODO: decide if we will support a samplesheet
    // SUBWORKFLOW: Validate and stage input files
    //
    INPUT_CHECK (
        ch_input,
        tuple([id: 'test'], ch_scorefile)
    )

    PLINK_VCF (
        INPUT_CHECK.out.vcf
    )
    ch_software_versions = ch_software_versions.mix(PLINK_VCF.out.versions.ifEmpty(null))

    // plink and input bed / bim channel will always have one element empty
    // so to make a combined channel just mix the two
    SPLIT(
        PLINK_VCF.out.bed.concat(INPUT_CHECK.out.bed),
        PLINK_VCF.out.bim.concat(INPUT_CHECK.out.bim),
        PLINK_VCF.out.fam.concat(INPUT_CHECK.out.fam),
        "chromosome"
    )
    // TODO: get mawk version
    // ch_software_versions = ch_software_versions.mix(SPLIT.out.versions.ifEmpty(null))

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
