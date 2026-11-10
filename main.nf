#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/pgscatalog/pgsc_calc
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { samplesheetToList; validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

include { PGSC_CALC  } from './workflows/pgsc_calc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow PGSCATALOG_PGSC_CALC {

    take:
    samplesheet // Channel: samplesheet read in from --input

    main:

    versions = Channel.empty()

    if (System.getenv('NXF_OFFLINE')) {
        def inputs = [params.input, params.scorefile, params.chain_files, params.genotype_cache_zip, params.sex_map]
        if (inputs.any { it && it.toString() =~ /[A-Za-z][A-Za-z0-9+.-]*:\/\// })
            error 'Offline execution requires local input files. Download analysis inputs beforehand.'
    }

    // validate parameters
    validateParameters()
    log.info paramsSummaryLog(workflow)

    // warn about the test profile
    if (workflow.profile.contains("test")) {
        log.info("The test profile is used to install the workflow and verify the software is working correctly on your system.")
        log.info("Test input data and results are are only useful as examples of outputs, and are not biologically meaningful.")
    }

    // be clear about liftover
    if (file(params.chain_files).baseName != "CHAIN_NO_FILE" & params.scorefile == null) {
        log.warn("Chain files are never needed for PGS Catalog scoring files")
        log.warn("Liftover is only useful for user-generated custom scoring files set by --scorefile")
        error("Remove --chain_files parameter unless you also set --scorefile")
    }

    if (System.getenv('NXF_OFFLINE')) {
        if (file(params.input).text =~ /(?i)(https?|ftp|s3|gs|az):\/\//)
            error 'The samplesheet contains remote paths. Prepare local genotype, index and sample files before offline execution.'
    }

    // validate samplesheet
    def rows = samplesheetToList(params.input, "assets/schema_input.json")
    if (!rows) error 'The samplesheet is empty.'
    if (rows.collect { it[0].sampleset }.unique().size() != 1)
        error 'Exactly one sampleset is supported per run. Use separate runs for independently called cohorts.'
    def declarations = rows.collect { it[0].absent_variants ?: 'unobserved' }.unique()
    if (declarations.size() != 1) error 'Conflicting absent_variants declarations in the sampleset.'
    if (declarations[0] != 'unobserved') error 'Only absent_variants=unobserved is supported; homref is not implemented.'
    def leaves = []
    rows.each { row ->
        def meta = row[0]
        def hasChrom = meta.chrom != null && meta.chrom != [] && meta.chrom.toString() != ''
        def chrom = hasChrom ? meta.chrom.toString().replaceFirst(/^chr/, '').replaceFirst(/^0+/, '') : 'ALL'
        chrom = ['23':'X', '24':'Y', '25':'X', '26':'MT', 'XY':'X', 'M':'MT'].get(chrom, chrom)
        if (!(chrom ==~ /([1-9]|1[0-9]|2[0-2]|X|Y|MT|ALL)/))
            error "Unsupported chromosome: ${meta.chrom}. Use 1–22, X, Y, MT or an empty value for whole-genome input."
        meta.chrom = chrom
        meta.absent_variants = declarations[0]
        meta.shard = row[1].name
        def leaf = "${meta.sampleset}/${chrom}/${meta.shard}"
        if (leaf in leaves) error "Duplicate cache leaf: $leaf. Rename one genotype file."
        leaves << leaf
    }
    ch_input = Channel.fromList(rows)

    // check scorefiles are OK
    if (![params.scorefile, params.pgs_id, params.efo_id, params.pgp_id].any()) {
        error " ERROR: You didn't set any scores to use! Please set --scorefile, --pgs_id, --efo_id, or --pgp_id"
    }

    if (System.getenv('NXF_OFFLINE') && [params.pgs_id, params.pgp_id, params.efo_id].any { it })
        error 'Catalog downloads are disabled offline. Prepare local scoring files beforehand and use --scorefile.'

    def joinParam = { p -> p?.tokenize(",")?.join(" ") ?: "" }
    pgscatalog_accessions = [
        pgs_id: joinParam(params.pgs_id),
        pgp_id: joinParam(params.pgp_id),
        efo_id: joinParam(params.efo_id)
    ]

    def suppliedCache = file(params.genotype_cache_zip, checkIfExists: true)
    def publishedCache = file(params.outdir).resolve('genotypes.zarr.zip')
    if (params.publish_cache && publishedCache.exists() && suppliedCache.toRealPath() == publishedCache.toRealPath())
        error 'Choose a different --outdir when reusing a cache. Publication must not overwrite the supplied --genotype_cache_zip.'

    // a singleton value channel (reused by all loading processes)
    ch_cache = Channel.value(suppliedCache)

    // pgsc_calc score parameters
    // how many variants are stored in each zarr chunk?
    ch_batch_size = Channel.value(params.variant_batch_size)

    //
    // WORKFLOW: Run pipeline
    //
    PGSC_CALC (
        ch_input,
        params.target_build,
        pgscatalog_accessions,
        params.scorefile,
        file(params.chain_files),
        ch_cache,
        ch_batch_size,
        versions
    )
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // WORKFLOW: Run main workflow
    //
    PGSCATALOG_PGSC_CALC (
        params.input
    )
}

workflow.onComplete {
    if (workflow.success) {
        log.info "- [pgscatalog/pgsc_calc] Pipeline completed successfully -"
    }
}

workflow.onError {
    log.error "Pipeline failed: ${workflow.errorMessage}"
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
