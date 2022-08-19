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

if (![params.scorefile, params.pgs_id, params.trait_efo, params.pgp_id].any()) {
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

if (params.scorefile) {
    Channel.fromPath(params.scorefile, checkIfExists: true)
        .set { scorefiles }

    scorefiles
        .unique()
        .join(scorefiles)
        .set { unique_scorefiles }
}

def process_accessions(String accession) {
    if (accession) {
        return accession.replaceAll('\\s','').tokenize(',').unique().join(' ')
    } else {
        return ''
    }
}

def String unique_trait_efo = process_accessions(params.trait_efo)
def String unique_pgp_id    = process_accessions(params.pgp_id)
def String unique_pgs_id    = process_accessions(params.pgs_id)

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
    def accessions = [pgs_id: unique_pgs_id, pgp_id: unique_pgp_id,
                      trait_efo: unique_trait_efo]

    if (!accessions.every( { it.value == '' })) {
        DOWNLOAD_SCOREFILES ( accessions, params.target_build )
        scorefiles = DOWNLOAD_SCOREFILES.out.scorefiles.mix(unique_scorefiles)
    } else {
        scorefiles = unique_scorefiles
    }

    //
    // SUBWORKFLOW: Validate and stage input files
    //

    scorefiles.collect().set{ ch_scorefiles }

    if (run_input_check) {
        INPUT_CHECK (
            ch_input,
            params.format,
            ch_scorefiles,
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
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
 ========================================================================================
*/

