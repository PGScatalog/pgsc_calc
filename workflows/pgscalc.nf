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


if (params.platform == 'arm64') {
    profiles = summary_params['Core Nextflow options'].profile.tokenize(',')
    if (profiles.contains('singularity') | profiles.contains('conda')) {
        println "ERROR: arm64 platform only supports -profile docker"
        System.exit(1)
    }
}

// Check mandatory parameters
ch_input = Channel.fromPath(params.input, checkIfExists: true)

// Set up scorefile channels ---------------------------------------------------

if (![params.scorefile, params.accession, params.trait, params.publication].any()) {
    println " ERROR: You didn't set any scores to use! \
        Please set --scorefile, --accession, --trait, or --publication"
    System.exit(1)
}

if (!params.target_build) {
    println "ERROR: You didn't set the target build of your target genomes"
    println "Please set --target_build GRCh37 or --target_build GRCh38"
    System.exit(1)
}

unique_scorefiles = Channel.empty()
unique_accessions = Channel.empty()

if (params.scorefile) {
    Channel.fromPath(params.scorefile, checkIfExists: true)
        .map { [[accession: it.getBaseName()], it ] }
        .set { scorefiles }

    scorefiles
        .unique()
        .join(scorefiles)
        .set { unique_scorefiles }
}

if (params.accession) {
    Channel.fromList(params.accession.replaceAll('\\s','').tokenize(','))
        .unique() // tokenize to ensure unique
        .collect()
        .map { it.join(' ') } // join again for download_scorefiles script
        .set { unique_accessions }
}

ch_reference = Channel.empty()

if (params.ref) {
    Channel.fromPath(params.ref, checkIfExists: true)
        .set { ch_reference } 
}

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

include { DOWNLOAD_SCOREFILES  } from '../modules/local/download_scorefiles'

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
        DOWNLOAD_SCOREFILES ( unique_accessions, params.target_build )
        scorefiles = unique_scorefiles.mix(DOWNLOAD_SCOREFILES.out.scorefiles)
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
            ch_scorefile,
            ch_reference
        )
        ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    }

    //
    // SUBWORKFLOW: Make scoring file and target genomic data compatible
    //

    if (run_make_compatible) {
        MAKE_COMPATIBLE (
            INPUT_CHECK.out.geno,
            INPUT_CHECK.out.pheno,
            INPUT_CHECK.out.variants,
            INPUT_CHECK.out.vcf,
            INPUT_CHECK.out.scorefiles,
        )
        ch_versions = ch_versions.mix(MAKE_COMPATIBLE.out.versions)
    }

    //
    // SUBWORKFLOW: Apply a scoring file to target genomic data
    //

    if (run_apply_score) {
        APPLY_SCORE (
            MAKE_COMPATIBLE.out.geno,
            MAKE_COMPATIBLE.out.pheno,
            MAKE_COMPATIBLE.out.variants,
            MAKE_COMPATIBLE.out.scorefiles,
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
