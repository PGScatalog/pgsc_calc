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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


workflow PGSC_CALC {

    take:
    ch_input // channel: samplesheet read in from --input
    target_build
    pgscatalog_accessions // hashmap [pgs_id: , pgp_id:, efo_id: ]
    scorefile
    ch_chain_files
    ch_versions

    main:

    // download scoring files from PGS Catalog if any accession strings are set
    ch_scores = channel.empty()
    if ([pgscatalog_accessions.pgs_id, pgscatalog_accessions.pgp_id, pgscatalog_accessions.efo_id].every { it.value == "" }) {
        PGSC_CALC_DOWNLOAD(
            pgscatalog_accessions,
            target_build
        )
        ch_versions = ch_versions.mix(PGSC_CALC_DOWNLOAD.out.versions)
        ch_scores = PGSC_CALC_DOWNLOAD.out.scorefiles
    }

    // format all scoring files into a consistent structure
    // add local scoring files, not fetched via the PGS Catalog API
    def local_scores = scorefile ? channel.fromPath(scorefile) : channel.empty()
    ch_scores = local_scores.mix(ch_scores)

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
            case 'vcf'  -> file('BGEN_SAMPLE_NO_FILE')
            default     -> throw new IllegalArgumentException("Unknown file_format: ${meta.file_format}")
        }
        [meta, target_path, bgen_sample_path, file(target_path + ext, checkIfExists: true)]
    }

    ch_target_with_index = ch_input.map(addIndex)

    // make value (singleton) channels for scorefiles and the cache
    // because one load process will launch for each target genome
    ch_formatted_scorefiles = PGSC_CALC_FORMAT.out.scorefiles.collect()
    ch_zarr_zip = channel.value(file("ZARR_ZIP_NO_FILE"))

    PGSC_CALC_LOAD(
        ch_target_with_index, // meta, path(target), path(bgen_sample), path(target_index)
        ch_formatted_scorefiles, // [scorefile_1, ..., scorefile_n]
        ch_zarr_zip // path(zarr_zip)
    )
    ch_versions = ch_versions.mix(PGSC_CALC_LOAD.out.versions)

    // scoring is a single process
    ch_score_input = PGSC_CALC_LOAD.out.zarr_zip.collect()
    PGSC_CALC_SCORE(
        ch_score_input,
        ch_formatted_scorefiles
    )
    ch_versions = ch_versions.mix(PGSC_CALC_SCORE.out.versions)

    emit:
    summary_log = PGSC_CALC_SCORE.out.summary_log // channel: file(summary_log)
    variant_match_log = PGSC_CALC_SCORE.out.logs  // channel: file(zip_archive)
    scores = PGSC_CALC_SCORE.out.scores           // channel: file(csv.gz)
    versions = ch_versions                        // channel: [version1, version2, ...]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
