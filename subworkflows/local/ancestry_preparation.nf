#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

def drop_type(ArrayList it) {
    // [[meta hashmap], [file1, file2, file3]]
    m = it.first().clone()
    m.remove('type')
    return [m, it.last()]
}

def create_channel(LinkedHashMap row) {
    def meta = [:]
    meta.ref = row.reference
    meta.build = row.build

    if (row.type == 'king') {
        meta.type = 'king'
    } else {
        meta.type = 'plink2'
    }

    return [meta, file(row.url)]
}


process SETUP_PLINK_RESOURCE {
    input:
    tuple val(meta), path(pgen), path(psam), path(pvar)
    
    output:
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst")
    
    """
    # standardise plink prefix on pgen
    mv $psam ${pgen.simpleName}.psam
    plink2 --zst-decompress $pgen > ${pgen.simpleName}.pgen
    mv $pvar ${pgen.simpleName}.pvar.zst
    """
}


workflow {
  main:
    samplesheet = Channel.fromPath(params.reference)

    samplesheet
        .splitCsv(header: true).map { create_channel(it) }
        .branch {
            king: it.first().type == 'king'
            plink2: it.first().type  == 'plink2'
        }.set{ ref }

    ref.plink2
    // closure guarantees sort order: -> pgen, psam, pvar
    // important for processes to refer to file types correctly
        .groupTuple(size: 3, sort: { it.toString().split(".p")[-1] } )
    // dropping type after branch simplifies joining later
        .map { drop_type(it) }
        .take(1)
        .map { it.flatten() }
        .set { ch_plink }

    SETUP_PLINK_RESOURCE(ch_plink)

    ref.king
        .map { drop_type(it) }
        .join(ch_plink)
        .set { ch_raw_ref }

}
