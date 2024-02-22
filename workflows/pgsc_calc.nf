/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowPgscCalc.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEBUG OPTIONS TO HALT WORKFLOW EXECUTION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def run_ancestry_bootstrap = true
def run_input_check = true
def run_make_compatible = true
def run_match = true
def run_ancestry_assign = true
def run_ancestry_adjust = true
def run_apply_score = true
def run_report = true

if (params.only_bootstrap) {
    run_ancestry_bootstrap = true
    run_input_check = false
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_ancestry_adjust = true
    run_apply_score = false
    run_report = false
}

if (params.only_input) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_apply_score = false
    run_report = false
}

if (params.only_projection) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_compatible) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = false
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_match) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_score) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = true
    run_report = false
}

// always run ancestry if the reference database path is set
// (even if --skip_ancestry is true)
if (params.run_ancestry) {
    run_ancestry_assign = true
    run_ancestry_adjust = true
} else if (params.skip_ancestry) {
    run_ancestry_assign = false
    run_ancestry_adjust = false
}

// don't try to bootstrap if we're not estimating or adjusting
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
include { ANCESTRY_PROJECT  } from '../subworkflows/local/ancestry/ancestry_project'
include { APPLY_SCORE          } from '../subworkflows/local/apply_score'
include { REPORT               } from '../subworkflows/local/report'
include { DUMPSOFTWAREVERSIONS } from '../modules/local/dumpsoftwareversions'


/*
========================================================================================
    DEPRECATION WARNINGS
========================================================================================
*/

if (params.platform) {
    System.err.println "--platform has been deprecated to match nf-core framework"
    System.err.println "Please use -profile docker,arm instead"
    System.exit(1)
}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PGSCCALC {
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Create reference database for ancestry inference
    //
    if (run_ancestry_bootstrap) {
        if (params.run_ancestry) {
            log.info "Reference database provided: skipping bootstrap"
            ch_reference = Channel.fromPath(params.run_ancestry, checkIfExists: true)
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
    ch_scores = Channel.empty()
    if (params.scorefile) {
        ch_scores = ch_scores.mix(Channel.fromPath(params.scorefile, checkIfExists: true))
    }

    // make sure accessions look sensible before querying PGS Catalog
    def pgs_id = WorkflowPgscCalc.prepareAccessions(params.pgs_id, "pgs_id")
    def pgp_id = WorkflowPgscCalc.prepareAccessions(params.pgp_id, "pgp_id")
    def trait_efo = WorkflowPgscCalc.prepareAccessions(params.trait_efo, "trait_efo")
    def accessions = pgs_id + pgp_id + trait_efo

    if (!accessions.every { it.value == "" }) {
        DOWNLOAD_SCOREFILES(accessions, params.target_build)
        ch_versions = ch_versions.mix(DOWNLOAD_SCOREFILES.out.versions)
        ch_scores = ch_scores.mix(DOWNLOAD_SCOREFILES.out.scorefiles)
    }

    if (!params.scorefile && accessions.every { it.value == "" }) {
        Nextflow.error("No valid accessions or scoring files provided. Please double check --pgs_id, --pgp_id, --trait_efo, or --scorefile parameters")
    }

    //
    // SUBWORKFLOW: Validate and stage input files
    //

    if (run_input_check) {
        // flatten the score channel
        ch_scorefiles = ch_scores.collect()
        // chain files are optional input
        Channel.fromPath("$projectDir/assets/NO_FILE", checkIfExists: false).set { chain_files }
        if (params.hg19_chain && params.hg38_chain) {
            Channel.fromPath(params.hg19_chain, checkIfExists: true)
                .mix(Channel.fromPath(params.hg38_chain, checkIfExists: true))
                .collect()
                .set { chain_files }
        }

        INPUT_CHECK (
            params.input,
            params.format,
            ch_scorefiles,
            chain_files
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

    // reference allelic frequencies are optional inputs to scoring subworkflow
    ref_afreq = Channel.fromPath(file('NO_FILE'))
    intersect_count = Channel.fromPath(file('NO_FILE_INTERSECT_COUNT'))

    if (run_ancestry_assign) {
        intersection = Channel.empty()
        ref_geno = Channel.empty()
        ref_pheno = Channel.empty()
        ref_var = Channel.empty()

        ANCESTRY_PROJECT (
            MAKE_COMPATIBLE.out.geno,
            MAKE_COMPATIBLE.out.pheno,
            MAKE_COMPATIBLE.out.variants,
            MAKE_COMPATIBLE.out.vmiss,
            ch_reference,
            params.target_build
        )
        ch_versions = ch_versions.mix(ANCESTRY_PROJECT.out.versions)
        intersection = intersection.mix(ANCESTRY_PROJECT.out.intersection)
        ref_geno = ref_geno.mix(ANCESTRY_PROJECT.out.ref_geno)
        ref_pheno = ref_pheno.mix(ANCESTRY_PROJECT.out.ref_pheno)
        ref_var = ref_var.mix(ANCESTRY_PROJECT.out.ref_var)
        intersect_count = ANCESTRY_PROJECT.out.intersect_count

        if (params.load_afreq) {
            ref_afreq = ANCESTRY_PROJECT.out.ref_afreq
        }
    }

    //
    // SUBWORKFLOW: Match scoring files against target genomes
    //
    if (run_match) {
        if (run_ancestry_assign) {
            // intersected variants ( across ref & target ) are an optional input
            intersection = ANCESTRY_PROJECT.out.intersection
        } else {
            dummy_input = Channel.of(file('NO_FILE')) // dummy file that doesn't exist
            // associate each sampleset with the dummy file
            MAKE_COMPATIBLE.out.geno.map {
                meta = it[0].clone()
                meta = meta.subMap(['id'])
                // one dummy file for groupTuple() size in match subworkflow
                meta.n_chrom = 1
                return meta
            }
                .unique()
                .combine(dummy_input)
                .set { intersection }
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
        if (run_ancestry_assign) {
            MAKE_COMPATIBLE.out.geno
                .mix( ref_geno )
                .set { ch_geno }

            MAKE_COMPATIBLE.out.pheno
                .mix( ref_pheno )
                .set { ch_pheno }

            MAKE_COMPATIBLE.out.variants
                .mix( ref_var )
                .set { ch_variants }
        } else {
            MAKE_COMPATIBLE.out.geno.set { ch_geno }
            MAKE_COMPATIBLE.out.pheno.set { ch_pheno }
            MAKE_COMPATIBLE.out.variants.set { ch_variants }
        }

        APPLY_SCORE (
            ch_geno,
            ch_pheno,
            ch_variants,
            intersection,
            MATCH.out.scorefiles,
            ref_afreq
        )
        ch_versions = ch_versions.mix(APPLY_SCORE.out.versions)
    }

    if (run_report) {
        projections = Channel.empty()
        relatedness = Channel.empty()
        report_pheno = Channel.empty()

        if (run_ancestry_assign) {
            projections = projections.mix(ANCESTRY_PROJECT.out.projections)
            relatedness = relatedness.mix(ANCESTRY_PROJECT.out.relatedness)
            report_pheno = report_pheno.mix(ref_pheno)
        }

        REPORT (
            report_pheno,
            relatedness,
            APPLY_SCORE.out.scores,
            projections,
            INPUT_CHECK.out.log_scorefiles,
            MATCH.out.db,
            run_ancestry_assign,
            intersect_count
        )
    }


    // MODULE: Dump software versions for all tools used in the workflow
    //
    DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

workflow.onError {
    if (workflow.errorReport.contains("Process requirement exceeds available memory")) {
        println("🛑 Default resources exceed availability 🛑 ")
        println("💡 See here on how to configure pipeline: https://nf-co.re/docs/usage/configuration#tuning-workflow-resources 💡")
    }
}

/*
========================================================================================
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
 ========================================================================================
*/
