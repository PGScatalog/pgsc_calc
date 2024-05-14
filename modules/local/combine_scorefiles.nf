process COMBINE_SCOREFILES {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    path raw_scores
    path reference

    output:
    path "scorefiles.txt.gz", emit: scorefiles
    path "log_scorefiles.json", emit: log_scorefiles
    path "versions.yml"     , emit: versions

    script:
    def args = task.ext.args ?: ''

    if (params.liftover)
        """
        pgscatalog-combine -s $raw_scores \
            --liftover \
            -t $params.target_build \
            -o scorefiles.txt.gz \
            -l log_scorefiles.json \
            -c \$PWD \
            -m $params.min_lift \
            -v \
            $args

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
        END_VERSIONS
        """
    else
        """
        pgscatalog-combine -s $raw_scores \
            -t $params.target_build \
            -o scorefiles.txt.gz \
            -l log_scorefiles.json \
            -v \
            $args

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
        END_VERSIONS
        """
}
