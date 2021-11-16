// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process CHECK_OVERLAP {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4"
    } else {
        container "quay.io/biocontainers/mawk:1.3.4--h779adbc_4"
    }

    input:
    tuple val(meta), path(target), val(scoremeta), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "*.log"                             , emit: log
    path "versions.yml"                      , emit: versions

    script:
    """
    mawk \
        ${options.args} \
        -f ${projectDir}/bin/check_overlap.awk \
        ${target} \
        ${scorefile}
    sort -nk 1 scorefile > ${scoremeta.accession}.scorefile
    mv extract.log ${scoremeta.accession}.log


    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
