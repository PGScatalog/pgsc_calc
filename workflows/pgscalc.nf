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
]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Genotype input not specified!' }

// Set up score channels
if (!params.accession && params.scorefile) {
    scorefile = Channel.of([[accession: file(params.scorefile).getName()], file(params.scorefile)])
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

// Don't overwrite global params.modules, create a copy instead and use that within the main script.
def modules = params.modules.clone()

//
// MODULE: Local to the pipeline
//
include { GET_SOFTWARE_VERSIONS } from '../modules/local/get_software_versions' addParams( options: [publish_files : ['tsv':'']] )

//
// SUBWORKFLOW: Get scoring file from PGS Catalog
//
include { PGSCATALOG } from '../subworkflows/local/pgscatalog' addParams( options: [:] )

def plink_vcf_options = [:]
plink_vcf_options['args'] = "--keep-allele-order"

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check' addParams( options: [:] )

def match_variants_options = [:]
match_variants_options['args'] = "-v min_overlap=" + params.min_overlap

include { MAKE_COMPATIBLE } from '../subworkflows/local/make_compatible' addParams( match_variants_options: match_variants_options )

include { SPLIT_GENOMIC } from '../subworkflows/local/split_genomic' addParams( options: [:] )

include { APPLY_SCORE } from '../subworkflows/local/apply_score' addParams ( options: [:] )

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PGSCALC {
    ch_software_versions = Channel.empty()

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

    ch_software_versions = ch_software_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Split genetic data to improve parallelisation --------------
    //
    SPLIT_GENOMIC (
        INPUT_CHECK.out.bed,
        INPUT_CHECK.out.bim,
        INPUT_CHECK.out.fam,
        INPUT_CHECK.out.scorefile
    )

    //
    // SUBWORKFLOW: Make scoring file and target genomic data compatible
    //
    MAKE_COMPATIBLE (
        SPLIT_GENOMIC.out.bed,
        SPLIT_GENOMIC.out.bim,
        SPLIT_GENOMIC.out.fam,
        SPLIT_GENOMIC.out.scorefile
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

//    GET_SOFTWARE_VERSIONS (
//        ch_software_versions.map { it }.collect()
//    )
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
