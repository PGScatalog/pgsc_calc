process PGSC_CALC_FORMAT {
    label 'process_low'
    tag "${raw_scores}"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://ghcr.io/pgscatalog/pygscatalog:pgscatalog-utils-2.0.1-singularity'
        : 'docker.io/pgscatalog/pgscatalog-calc:0.1.2'}"

    input:
    path raw_scores, arity: '1.*'
    path chain_file, arity: '1'
    val target_build

    output:
    path "formatted/normalised_*.{txt,txt.gz}", arity: "1..*", emit: scorefiles
    path "formatted/log_scorefiles.json", arity: "1", emit: log_scorefiles
    path "versions.yml", arity: "1", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // add liftover argument if the chain file exists
    // (only applies to custom scoring files)
    def liftover = chain_file.name != 'CHAIN_NO_FILE' ? " -c \$PWD" : ''
    """
    mkdir formatted

    pgsc_calc format -s $raw_scores \
        -t $target_build \
        --threads $task.cpus \
        -o formatted/ \
        -l log_scorefiles.json \
        $liftover \
        -v

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
    END_VERSIONS
    """

    stub:
    """
    mkdir formatted
    touch formatted/normalised_PGS001229_hmPOS_GRCh38.txt.gz formatted/log_scorefiles.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
    END_VERSIONS
    """
}