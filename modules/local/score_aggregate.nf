process SCORE_AGGREGATE {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options
    tag "$meta.id"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(scorefiles)

    output:
    tuple val(scoremeta), path("*.txt.gz"), emit: scores
    path "versions.yml", emit: versions

    script:
    scoremeta = meta.subMap('id')
    """
    aggregate_scores -s $scorefiles -o . -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
