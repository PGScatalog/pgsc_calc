#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { DOWNLOAD_SCOREFILES } from '../../../modules/local/download_scorefiles.nf'

workflow testaccession {
    target_build = 'GRCh37'
    accessions = [pgs_id: 'PGS000001', pgp_id: '', trait_efo: '']

    DOWNLOAD_SCOREFILES(accessions, target_build)
}

workflow testmultipleaccessions {
    target_build = 'GRCh37'
    accessions = [pgs_id: 'PGS000001 PGS000002',
                  pgp_id: 'PGP000001',
                  trait_efo: 'EFO_0004214']

    DOWNLOAD_SCOREFILES(accessions, target_build)
}

workflow testbadaccession {
    target_build = 'GRCh37'
    accessions = [pgs_id: 'howdy',
                  pgp_id: '',
                  trait_efo: '']


    DOWNLOAD_SCOREFILES(accessions, target_build)
}

workflow testmixedaccessions {
    target_build = 'GRCh38'
    accessions = [pgs_id: 'howdy PGS000001',
                  pgp_id: '',
                  trait_efo: '']

    DOWNLOAD_SCOREFILES(accessions, target_build)
}
