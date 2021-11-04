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

def validate_extract_options = [:]
if (params.min_overlap) { validate_extract_options['args'] = "-v threshold=" + params.min_overlap }

include { MAKE_COMPATIBLE } from '../subworkflows/local/make_compatible' addParams( validate_extract_options: validate_extract_options )

// include { SPLIT } from '../subworkflows/local/split' addParams( options: [:] )

include { APPLY_SCORE } from '../subworkflows/local/apply_score' addParams ( options: [:] )

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

    //
    // SUBWORKFLOW: Validate and stage input files
    //
    INPUT_CHECK (
        ch_input,
        tuple([id: 'test'], ch_scorefile)
    )
    ch_software_versions = ch_software_versions.mix(INPUT_CHECK.out.versions)

    //
    // MODULE: VCF to BFILE
    //
    PLINK_VCF (
        INPUT_CHECK.out.vcf
    )
    ch_software_versions = ch_software_versions.mix(PLINK_VCF.out.versions)

    //
    // SUBWORKFLOW: Make scoring file and target genomic data compatible
    //
    MAKE_COMPATIBLE (
        PLINK_VCF.out.bed.concat(INPUT_CHECK.out.bed),
        PLINK_VCF.out.bim.concat(INPUT_CHECK.out.bim),
        PLINK_VCF.out.fam.concat(INPUT_CHECK.out.fam),
        INPUT_CHECK.out.scorefile
    )
    ch_software_versions = ch_software_versions.mix(MAKE_COMPATIBLE.out.versions)

    //
    // SUBWORKFLOW: Apply a scoring file to target genomic data
    //
    APPLY_SCORE (
        MAKE_COMPATIBLE.out.pgen,
        MAKE_COMPATIBLE.out.psam,
        MAKE_COMPATIBLE.out.pvar,
        MAKE_COMPATIBLE.out.scorefile
    )

    // SPLIT(
    //     PLINK_VCF.out.bed.concat(INPUT_CHECK.out.bed),
    //     PLINK_VCF.out.bim.concat(INPUT_CHECK.out.bim),
    //     PLINK_VCF.out.fam.concat(INPUT_CHECK.out.fam),
    //     "chromosome"
    // )

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
