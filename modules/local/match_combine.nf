process MATCH_COMBINE {
    tag "$meta.id"
    scratch true
    label 'process_medium'
    errorStrategy 'finish'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"

    input:
    tuple val(meta), val(chrom), path('???.ipc.zst'), path(scorefile), path(shared)

    output:
    tuple val(scoremeta), path("*.scorefile.gz"), emit: scorefile
    path "*_summary.csv"                        , emit: summary
    path "*_log.csv.gz"                         , emit: db
    path "versions.yml"                         ,  emit: versions

    script:
    def args  = task.ext.args               ?: ''
    def ambig = params.keep_ambiguous       ? '--keep_ambiguous'    : ''
    def multi = params.keep_multiallelic    ? '--keep_multiallelic' : ''
    def split = !chrom.contains("ALL") ? '--split' : ''
    def filter_mode = shared.name != 'NO_FILE' ? "" : '' // "--filter_IDs $shared" : ''
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    """
    export POLARS_MAX_THREADS=$task.cpus

    combine_matches \
        $args \
        --dataset $meta.id \
        --scorefile $scorefile \
        --matches *.ipc.zst \
        -n $task.cpus \
        --min_overlap $params.min_overlap \
        $ambig \
        $multi \
        $filter_mode \
        --outdir \$PWD \
        $split \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
