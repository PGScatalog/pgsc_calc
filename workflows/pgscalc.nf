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
        Please set --scorefile, --pgs_id, --trait_efo, or --pgp_id"
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


def run_ancestry_bootstrap = true
def run_input_check = true
def run_make_compatible = true
def run_match = true
def run_ancestry_assign = true
def run_ancestry_adjust = true
def run_apply_score = true

if (params.only_bootstrap) {
    run_ancestry_bootstrap = true
    run_input_check = false
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_ancestry_adjust = false
    run_apply_score = false
}

if (params.only_input) {
    run_ancestry_bootstrap = false
    run_input_check = true
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_apply_score = false
}

if (params.only_compatible) {
    run_ancestry_bootstrap = false
    run_input_check = true
    run_make_compatible = true
    run_match = false
    run_ancestry_assign = false
    run_apply_score = false
}

if (params.only_projection) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = false
}

if (params.only_score) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = false
    run_apply_score = true
}

if (!run_ancestry_assign && !run_ancestry_adjust) {
    run_ancestry_bootstrap = false
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { DOWNLOAD_SCOREFILES  } from '../modules/local/download_scorefiles'

include { BOOTSTRAP_ANCESTRY   } from '../subworkflows/local/ancestry/bootstrap_ancestry'
include { INPUT_CHECK          } from '../subworkflows/local/input_check'
include { MAKE_COMPATIBLE      } from '../subworkflows/local/make_compatible'
include { MATCH                } from '../subworkflows/local/match'
include { ANCESTRY_PROJECTION  } from '../subworkflows/local/ancestry/ancestry_projection'
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
    // SUBWORKFLOW: Create reference database for ancestry inference
    //
    if (run_ancestry_bootstrap) {
        if (params.ref) {
            log.info "Reference database provided: skipping bootstrap"
            ch_reference = Channel.fromPath(params.ref, checkIfExists: true)
        } else {
            log.info "Creating ancestry database from source data"
            reference_samplesheet = Channel.fromPath(params.ref_samplesheet)
            BOOTSTRAP_ANCESTRY ( reference_samplesheet )
            ch_reference = BOOTSTRAP_ANCESTRY.out.reference_database
            ch_versions = ch_versions.mix(BOOTSTRAP_ANCESTRY.out.versions)
        }
    }

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

        )
        ch_versions = ch_versions.mix(MAKE_COMPATIBLE.out.versions)
    }


    //
    // SUBWORKFLOW: Run ancestry projection
    //
    if (run_ancestry_assign) {
        ANCESTRY_PROJECTION (
            MAKE_COMPATIBLE.out.geno,
            MAKE_COMPATIBLE.out.pheno,
            MAKE_COMPATIBLE.out.variants,
            MAKE_COMPATIBLE.out.vmiss,
            ch_reference,
            params.target_build
        )
        ch_versions = ch_versions.mix(ANCESTRY_PROJECTION.out.versions)
    }

    //
    // TODO: Set up optional input of intersected variants for MAKE_COMPATIBLE
    //
    if (run_ancestry_adjust) {
        // TODO: set up optional input of intersected variants here for run_apply_score

    }

    //
    // SUBWORKFLOW: Match scoring files against target genomes
    //
    if (run_match) {
        if (run_ancestry_assign) {
            // intersected variants ( across ref & target ) are an optional input
            intersection = ANCESTRY_PROJECTION.out.intersection
        } else {
            intersection = Channel.of(file('NO_FILE')) // dummy file with fake name
        }

        MATCH (
            MAKE_COMPATIBLE.out.geno,
            MAKE_COMPATIBLE.out.pheno,
            MAKE_COMPATIBLE.out.variants,
            INPUT_CHECK.out.scorefiles,
            intersection
        )
        ch_versions = ch_versions.mix(MATCH.out.versions)
    }


    //
    // SUBWORKFLOW: Apply a scoring file to target genomic data
    //

    if (run_apply_score) {
        APPLY_SCORE (
            MAKE_COMPATIBLE.out.geno,
            MAKE_COMPATIBLE.out.pheno,
            MAKE_COMPATIBLE.out.variants,
            MATCH.out.scorefiles,
            INPUT_CHECK.out.log_scorefiles,
            MATCH.out.db
        )
        ch_versions = ch_versions.mix(APPLY_SCORE.out.versions)
    }



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
    println "Please remember to cite polygenic score authors if you publish with them!"
    println "Check the output report for citation details"
}

/*
========================================================================================
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
 ========================================================================================
*/

