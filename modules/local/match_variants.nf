// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5 sqlite" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/pandas:1.1.5"
    } else {
        container "quay.io/biocontainers/pandas:1.1.5"
    }

    input:
    tuple val(meta), path(target), val(scoremeta), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "*.log"                             , emit: log
    path "versions.yml"                      , emit: versions

    script:
    """
    match_variants.py \
        $options.args \
        --scorefile $scorefile \
        --target $target \
        --db match.db \
        --out ${meta.id}.scorefile

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
        sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
    END_VERSIONS
    """
}
