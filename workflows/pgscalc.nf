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
    .unique()
    .set { unique_accessions }

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { PGSCATALOG           } from '../subworkflows/local/pgscatalog'
include { INPUT_CHECK          } from '../subworkflows/local/input_check'
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
        unique_accessions
    )

    unique_scorefiles.mix( PGSCATALOG.out.scorefile ).map { it[1] }.collect().set{ ch_scorefile }

    //
    // SUBWORKFLOW: Validate and stage input files
    //

    INPUT_CHECK (
        ch_input,
        params.format,
        ch_scorefile
    )

    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    // SUBWORKFLOW: Split genetic data to improve parallelisation --------------
    //

    SPLIT_GENOMIC (
        INPUT_CHECK.out.bed,
        INPUT_CHECK.out.bim,
        INPUT_CHECK.out.fam,
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
