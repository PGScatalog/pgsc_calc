/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//

include { PGSC_CALC_DOWNLOAD } from '../..//modules/local/download'
include { PGSC_CALC_FORMAT   } from '../..//modules/local/format'
include { PGSC_CALC_LOAD     } from '../..//modules/local/load'
include { PGSC_CALC_SCORE    } from '../..//modules/local/score'
include { PGSC_CALC_REPORT    } from '../..//modules/local/report'

include { PGSC_CALC_MATCH } from '../../modules/local/match'
include { PGSC_CALC_MATCH_COMBINE } from '../../modules/local/match_combine'
include { PGSC_CALC_SCORE_COMBINE } from '../../modules/local/score_combine'
include { PGSC_CALC_CACHE_PACK } from '../../modules/local/cache_pack'
include { PGSC_CALC_CHECK_SAMPLES } from '../../modules/local/check_samples'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow PGSC_CALC {

    take:
    ch_input // Channel: samplesheet read in from --input
    target_build
    pgscatalog_accessions // hashmap [pgs_id: , pgp_id:, efo_id: ]
    scorefile
    ch_chain_files
    ch_cache // file(genotypes.zarr.zip) value channel
    batch_size // int value channel
    ch_versions

    main:

    // download scoring files from PGS Catalog if any accession strings are set
    ch_scores = Channel.empty()

    def any_pgscatalog_query = [pgscatalog_accessions.pgs_id, pgscatalog_accessions.pgp_id, pgscatalog_accessions.efo_id].any { it }
    if (any_pgscatalog_query) {
        log.info "Data requested from PGS Catalog"
        PGSC_CALC_DOWNLOAD(
            pgscatalog_accessions,
            target_build
        )
        ch_versions = ch_versions.mix(PGSC_CALC_DOWNLOAD.out.versions)
        ch_scores = PGSC_CALC_DOWNLOAD.out.scorefiles
    } else {
        log.info "No PGS Catalog data requested"
    }

    // format all scoring files into a consistent structure
    // add local scoring files, not fetched via the PGS Catalog API
    if (scorefile) {
        local_scores = Channel.fromPath(scorefile, checkIfExists: true)
    } else {
        local_scores = Channel.empty()
    }

    ch_scores = local_scores.mix(ch_scores).collect().dump(tag: 'scorefiles')

    PGSC_CALC_FORMAT(
        ch_scores,
        ch_chain_files,
        target_build
    )
    ch_versions = ch_versions.mix(PGSC_CALC_FORMAT.out.versions)

    // automatically add index files
    // it's important that index files are input to the process so they are staged correctly
    def addIndex = { meta, target_path, sample_path ->
        def ext = switch(meta.file_format) {
            case 'bgen' -> '.bgi'
            case 'vcf'  -> '.csi'
            default     -> throw new IllegalArgumentException("Unknown file_format: ${meta.file_format}")
        }
        def bgen_sample_path = switch(meta.file_format) {
            case 'bgen' -> sample_path
            case 'vcf'  -> file("$projectDir/assets/optional_input/BGEN_SAMPLE_NO_FILE", checkIfExists: true)
            default     -> throw new IllegalArgumentException("Unknown file_format: ${meta.file_format}")
        }
        def target_index = target_path.resolveSibling(target_path.getName() + ext)
        [meta, target_path, bgen_sample_path, target_index]
    }

    ch_target_with_index = ch_input.map(addIndex)


    // make value (singleton) channels for scorefiles and the cache
    // because one load process will launch for each target genome
    ch_formatted_scorefiles = PGSC_CALC_FORMAT.out.scorefiles.collect()

    PGSC_CALC_LOAD(
        ch_target_with_index, // meta, path(target), path(bgen_sample), path(target_index)
        ch_formatted_scorefiles, // [scorefile_1, ..., scorefile_n]
        ch_cache, // path(zarr_zip)
        batch_size, // value(int)
        file(params.sex_map, checkIfExists: true)
    )
    ch_versions = ch_versions.mix(PGSC_CALC_LOAD.out.versions)

    // Every LOAD reports its samples, including shards with no requested variants.
    PGSC_CALC_CHECK_SAMPLES(PGSC_CALC_LOAD.out.loaded.map { meta, cache -> cache }.collect())
    ch_loaded = PGSC_CALC_LOAD.out.loaded.combine(PGSC_CALC_CHECK_SAMPLES.out.validated)
        .filter { meta, cache, validated -> cache.resolve('genotypes.zarr.zip').exists() }
        .map { meta, cache, validated -> [meta, cache.resolve('genotypes.zarr.zip')] }
    PGSC_CALC_MATCH(ch_loaded.map { meta, cache -> [meta.chrom, cache] }.groupTuple(), ch_formatted_scorefiles)
    ch_sampleset = ch_target_with_index.map { it[0].sampleset }.first()
    PGSC_CALC_MATCH_COMBINE(
        PGSC_CALC_MATCH.out.matches.map { chrom, matches, samples -> matches }.collect(),
        PGSC_CALC_MATCH.out.matches.map { chrom, matches, samples -> samples }.collect(),
        ch_formatted_scorefiles, ch_sampleset)
    PGSC_CALC_SCORE(ch_loaded, PGSC_CALC_MATCH_COMBINE.out.table, ch_formatted_scorefiles)
    PGSC_CALC_SCORE_COMBINE(PGSC_CALC_SCORE.out.partials.collect())
    if (params.publish_cache) {
        PGSC_CALC_CACHE_PACK(ch_loaded.map { meta, cache -> cache }.collect())
    }
    ch_versions = ch_versions.mix(PGSC_CALC_MATCH.out.versions)
        .mix(PGSC_CALC_MATCH_COMBINE.out.versions)
        .mix(PGSC_CALC_SCORE.out.versions)
        .mix(PGSC_CALC_SCORE_COMBINE.out.versions)

    // create some value channels for the report
    ch_scores = PGSC_CALC_SCORE_COMBINE.out.scores.collect()
    ch_score_log = PGSC_CALC_FORMAT.out.log_scorefiles.collect()
    ch_match_summary = PGSC_CALC_MATCH_COMBINE.out.summary_log.collect()
    ch_match_parameters = Channel.value([params.keep_multiallelic, params.keep_ambiguous, params.min_overlap, params.ignore_strand_flips])
    ch_report_files = Channel.fromPath("$baseDir/assets/report/*", checkIfExists: true).collect()

    PGSC_CALC_REPORT (
        ch_sampleset,
        ch_scores,
        ch_score_log,
        ch_match_summary,
        ch_match_parameters,
        ch_report_files
    )
    ch_versions = ch_versions.mix(PGSC_CALC_REPORT.out.versions)

    emit:
    summary_log = ch_match_summary // Channel: file(summary_log)
    variant_match_log = PGSC_CALC_MATCH_COMBINE.out.logs  // Channel: file(zip_archive)
    scores = PGSC_CALC_SCORE_COMBINE.out.scores           // Channel: file(csv.gz)
    report = PGSC_CALC_REPORT.out.report
    versions = ch_versions                        // Channel: [version1, version2, ...]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
