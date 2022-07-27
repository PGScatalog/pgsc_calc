#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { DOWNLOAD_SCOREFILES } from '../../../modules/local/download_scorefiles.nf'

workflow testaccession {
    input = 'PGS000001'

    DOWNLOAD_SCOREFILES(input)
}

workflow testmultipleaccessions {
    input = 'PGS000001 PGS000002'

    DOWNLOAD_SCOREFILES(input)
}

workflow testbadaccession {
    input = 'howdy'

    DOWNLOAD_SCOREFILES(input)
}

workflow testmixedaccessions {
    input = 'howdy PGS000001'

    DOWNLOAD_SCOREFILES(input)
}
