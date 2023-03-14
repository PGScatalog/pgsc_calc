process ANCESTRY_ANALYSIS {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple path(scores), path(relatedness), path('???.pcs')

    output:
    path "results.csv", emit: results
    path "versions.yml", emit: versions

    script:
    """
    touch results.csv

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
