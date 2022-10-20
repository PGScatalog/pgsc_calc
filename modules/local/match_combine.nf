process MATCH_COMBINE {
    tag "$meta.id"
    label 'process_medium'
    errorStrategy 'finish'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"

    input:
    tuple val(meta), path('??.ipc.zst'), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile.gz"), emit: scorefile
    path "*_summary.csv"                        , emit: summary
    path "*_log.csv.gz"                         , emit: db
    path "versions.yml"                         ,  emit: versions

    script:
    def args = task.ext.args                ?: ''
    scoremeta = [:]
    scoremeta.id = "$meta.id"
    """
    export POLARS_MAX_THREADS=$task.cpus

    combine_matches \
        $args \
        --min_overlap $params.min_overlap \
        --dataset $meta.id \
        --scorefile $scorefile \
        --matches '*.ipc.zst' \
        --outdir \$PWD \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
