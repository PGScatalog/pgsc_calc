//
// Get PGSCatalog scoring file from a PGS accession
//

include { PGSCATALOG_API } from '../../modules/local/pgscatalog_api'
include { PGSCATALOG_PARSE } from '../../modules/local/pgscatalog_parse'
include { PGSCATALOG_GET } from '../../modules/local/pgscatalog_get'

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

    PGSCATALOG_GET.out.scorefile
        .map { [[accession: it.head()], it.tail()].flatten() }
        .set { ch_scorefile }

    emit:
    scorefile = ch_scorefile // channel: [ tuple val(meta), path(scorefile) ]
    versions = ch_versions // channel: [ versions.yml ]
}
