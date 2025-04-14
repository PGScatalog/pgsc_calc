#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { DOWNLOAD_SCOREFILES } from '../../../modules/local/download_scorefiles.nf'
include { FORMAT_SCOREFILES } from '../../../modules/local/format_scorefiles.nf'

workflow testformat {

    target_build = 'GRCh38'
    accessions = [pgs_id: 'PGS000001 PGS000002',
                  pgp_id: 'PGP000001',
                  trait_efo: 'EFO_0004214']

    Channel.fromPath('NO_FILE', checkIfExists: false).set { chain_files }

    DOWNLOAD_SCOREFILES(accessions, target_build)

    FORMAT_SCOREFILES ( DOWNLOAD_SCOREFILES.out.scorefiles, chain_files )
}
