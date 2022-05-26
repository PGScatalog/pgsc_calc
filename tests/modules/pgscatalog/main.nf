#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PGSCATALOG_GET } from '../../../modules/local/pgscatalog_get.nf'

workflow testaccession {
    input = 'PGS000001'

    PGSCATALOG_GET(input)
}

workflow testmultipleaccessions {
    input = 'PGS000001,PGS000002'

    PGSCATALOG_GET(input)
}

workflow testbadaccession {
    input = 'howdy'

    PGSCATALOG_GET(input)
}

workflow testmixedaccessions {
    input = 'howdy,PGS000001'

    PGSCATALOG_GET(input)
}
