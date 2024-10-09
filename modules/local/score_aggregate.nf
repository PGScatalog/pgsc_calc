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
    tuple val(meta), path(scorefiles) // calculated polygenic scores
    path(scorefile_vars) // PGS scoring file
    path(scored_vars) // variants _actually used_ to calculate scores

    output:
    tuple val(scoremeta), path("aggregated_scores.txt.gz"), emit: scores
    path "versions.yml", emit: versions

    script:
    scoremeta = meta.subMap('id')
    """
    # variants are always verified, so that variants in the scoring files
    # overlap perfectly with the scored variants
    pgscatalog-aggregate -s $scorefiles -o . -v --no-split --verify_variants

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """
}
