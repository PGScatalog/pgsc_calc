#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { SETUP_RESOURCE } from '../../../modules/local/ancestry/setup_resource'
include { PLINK2_RELABELPVAR } from '../../../modules/local/plink2_relabelpvar'
include { QUALITY_CONTROL } from '../../../modules/local/ancestry/quality_control'


workflow BOOTSTRAP_ANCESTRY {
    main:
    // TODO: replace with take: section when integrating
    samplesheet = Channel.fromPath(params.reference)

    samplesheet
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

    PLINK2_RELABELPVAR( SETUP_RESOURCE.out.plink )

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

    QUALITY_CONTROL.out.plink
        .flatten()
        .filter(Path)
        .collect()
    // [geno, pheno, var, ..., geno, pheno, var]
        .set { ch_qc_ref }

    MAKE_DATABASE( ch_qc_ref )
}

process MAKE_DATABASE {
    stageInMode: 'copy' // for creation of database
    afterScript 'find . -not -name "*.sqlar"' // TODO: clean up copied files

    label 'process_low'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"

    input:
    path '*'

    """
    # TODO: grab chain files
    # TODO: think about globbing in the database
    ls
    """
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
