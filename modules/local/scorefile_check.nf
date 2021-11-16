// Import generic module functions
include { initOptions; saveFiles; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process SCOREFILE_CHECK {
    tag "$meta.accession"
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
    tuple val(meta), path(datafile)

    output:
    tuple val(meta), path("*.txt"), emit: data
    path "versions.yml"           , emit: versions

    script:
    def prefix  = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    mawk -v out=${prefix}_checked.txt \
        -f ${projectDir}/bin/check_scorefile.awk \
        ${datafile}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
