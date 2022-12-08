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
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst"), emit: plink
    
    """
    # standardise plink prefix on pgen
    mv $psam ${pgen.simpleName}.psam
    plink2 --zst-decompress $pgen > ${pgen.simpleName}.pgen
    mv $pvar ${pgen.simpleName}.pvar.zst
    """
}

process QUALITY_CONTROL {
    input:
    tuple val(meta), path(king), path(pgen), path(psam), path(pvar)

    output:
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst"), emit: plink

    """
    plink2 --zst-decompress $pvar \
        | grep -vE "^#" \
        | awk '{if(\$4 \$5 == "AT" || \$4 \$5 == "TA" || \$4 \$5 == "CG" || \$4 \$5 == "GC") print \$3}' \
        > 1000G_StrandAmb.txt

    plink2 --pfile ${pgen.simpleName} vzs \
        --remove $king \
        --exclude 1000G_StrandAmb.txt \
        --max-alleles 2 \
        --snps-only just-acgt \
        --rm-dup exclude-all \
        --geno 0.1 \
        --mind 0.1 \
        --maf 0.01 \
        --hwe 0.000001 \
        --autosome \
        --make-pgen vzs \
        --allow-extra-chr \
        --out ${pgen.simpleName}_qc
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
    // TODO: remove
        .take(1)
        .map { it.flatten() }
        .set { ch_plink }

    SETUP_PLINK_RESOURCE(ch_plink)

    ref.king
        .map { drop_type(it) }
        .join(SETUP_PLINK_RESOURCE.out.plink)
        .set { ch_raw_ref }

    QUALITY_CONTROL(ch_raw_ref)

    QUALITY_CONTROL.out.plink.view()
}
