// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MAWK_SPLITBIM {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4"
    } else {
        container "quay.io/biocontainers/mawk:1.3.4--h779adbc_4"
    }

    input:
    tuple val(meta), path(bim)
    val split_mode

    output:
    tuple val(meta), path("*.keep"), emit: variants
    path "versions.yml"            , emit: versions

    // specify path with -f manually for portability (mawk can live lots of places)
    // env won't work with parameters too!
    script:
    def prefix   = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"
    """
    mawk -v split_mode=${split_mode} \
        -f ${projectDir}/bin/split_bim.awk \
        ${bim}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
