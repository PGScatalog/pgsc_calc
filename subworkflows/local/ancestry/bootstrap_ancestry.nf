#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { SETUP_RESOURCE } from '../../../modules/local/ancestry/setup_resource'
include { PLINK2_RELABELPVAR } from '../../../modules/local/plink2_relabelpvar'
include { QUALITY_CONTROL } from '../../../modules/local/ancestry/quality_control'
include { MAKE_DATABASE } from '../../../modules/local/ancestry/make_database'

workflow BOOTSTRAP_ANCESTRY {
    take:
    reference_samplesheet

    main:
    ch_versions = Channel.empty()

    reference_samplesheet
        .splitCsv(header: true).map { create_ref_input_channel(it) }
        .branch {
            king: !it.first().is_pfile
            plink2: it.first().is_pfile
        }
        .set{ ref }

    ref.plink2
    // closure guarantees sort order: -> pgen, psam, pvar
    // important for processes to refer to file types correctly
        .groupTuple(size: 3, sort: { it.toString().split(".p")[-1] } )
        .map { it.flatten() }
        .set { ch_plink }

    SETUP_RESOURCE( ch_plink )
    ch_versions = ch_versions.mix(SETUP_RESOURCE.out.versions)

    PLINK2_RELABELPVAR( SETUP_RESOURCE.out.plink )
    ch_versions = ch_versions.mix(PLINK2_RELABELPVAR.out.versions.first())

    PLINK2_RELABELPVAR.out.geno
        .concat(PLINK2_RELABELPVAR.out.pheno, PLINK2_RELABELPVAR.out.variants)
        .groupTuple(size: 3)
        .map { drop_meta_keys(it).flatten() }
        .set{ relabelled }

    ref.king
        .map { drop_meta_keys(it) }
    // dropping meta keys simplifies the join
        .join( relabelled )
        .set { ch_raw_ref }

    QUALITY_CONTROL(ch_raw_ref)
    ch_versions = ch_versions.mix(QUALITY_CONTROL.out.versions.first())

    // grab chain files
    hg19tohg38 = Channel.fromPath("https://hgdownload.cse.ucsc.edu/goldenpath/hg19/liftOver/hg19ToHg38.over.chain.gz")
    hg38tohg19 = Channel.fromPath("https://hgdownload.soe.ucsc.edu/goldenPath/hg38/liftOver/hg38ToHg19.over.chain.gz")

    QUALITY_CONTROL.out.plink
        .flatten()
        .filter(Path) // drop meta hashmaps
        .concat( hg19tohg38, hg38tohg19 )
        .flatten()
        .collect()
        .set { ch_qc_ref }

    MAKE_DATABASE( ch_qc_ref )
    ch_versions = ch_versions.mix(MAKE_DATABASE.out.versions)

    emit:
    reference_database = MAKE_DATABASE.out.reference
    versions = ch_versions
}


def drop_meta_keys(ArrayList it) {
    // input: [[meta hashmap], [file1, file2, file3]]
    // cloning is important when modifying the hashmap
    m = it.first().clone()
    // dropping keys simplifies joining with build specific reference data
    m.remove('type')
    m.remove('is_pfile')
    return [m, it.last()]
}


def create_ref_input_channel(LinkedHashMap row) {
    def meta = [:]
    meta.id = row.reference
    meta.build = row.build
    meta.chrom = "ALL"

    if (row.type == 'king') {
        meta.is_pfile = false
    } else {
        meta.is_pfile = true
    }

    return [meta, file(row.url)]
}
