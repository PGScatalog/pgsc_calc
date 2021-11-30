//
// Get PGSCatalog scoring file from a PGS accession
//

include { PGSCATALOG_API } from '../../modules/local/pgscatalog_api'
include { PGSCATALOG_PARSE } from '../../modules/local/pgscatalog_parse'
include { PGSCATALOG_GET } from '../../modules/local/pgscatalog_get'
include { GUNZIP } from '../../modules/nf-core/modules/gunzip/main'

workflow PGSCATALOG {
    take:
    accession

    main:
    ch_versions = Channel.empty()

    //
    // Query PGSCatalog REST API
    //
    PGSCATALOG_API(accession)
    ch_versions = ch_versions.mix(PGSCATALOG_API.out.versions)

    //
    // Parse JSON response
    //
    PGSCATALOG_PARSE(PGSCATALOG_API.out.json)
    ch_versions = ch_versions.mix(PGSCATALOG_PARSE.out.versions)

    //
    // Download ftp scoring file
    //
    PGSCATALOG_GET(PGSCATALOG_PARSE.out.url)
    ch_versions = ch_versions.mix(PGSCATALOG_GET.out.versions)

    GUNZIP(PGSCATALOG_GET.out.scorefile)

    // TODO: improve this to support multiple accessions
    // concat will stop working
    // channel 1: [id: accession1], [id:accession2]
    // channel 2: [accession1.txt. accession2.txt]
    // want to combine using some groovy loop (not combine / cross)
    Channel.from(accession)
    // changing this to [id: it] breaks? wtf?
    // ah, wd contains $accession.txt, so changing breaks this file weirdly
        .map { [accession: it] }
        .concat(GUNZIP.out.gunzip)
        .buffer( size: 2 )
        .set { ch_scorefile }

    ch_versions = ch_versions.mix(GUNZIP.out.versions)

    emit:
    scorefile = ch_scorefile // channel: [ tuple val(meta), path(scorefile) ]
    versions = ch_versions // channel: [ versions.yml ]
}
