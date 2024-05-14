process MATCH_COMBINE {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'error_retry'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    // first element of tag must be sampleset
    tag "$meta.id"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path('???.ipc.zst'), path(scorefile), path(shared)

    output:
    tuple val(scoremeta), path("*.scorefile.gz"), emit: scorefile
    path "*_summary.csv"                        , emit: summary
    path "*_log.csv.gz"                         , emit: db
    path "versions.yml"                         ,  emit: versions

    script:
    def args  = task.ext.args               ?: ''
    def ambig = params.keep_ambiguous       ? '--keep_ambiguous'    : ''
    def multi = params.keep_multiallelic    ? '--keep_multiallelic' : ''
    // output one (or more) scoring files per chromosome?
    def split_output = meta.split ? '--split' : ''
    // output one (or more) scoring file per sampleset?
    def combined_output = (!meta.split || shared.name != 'NO_FILE') ? '--combined' : ''
    // filter match candidates to intersect with reference:
    // omit multi-allelic variants in reference because these will cause errors with relabelling!...
    // ... unclear whether we should remove them from target with '&& ($9 == 0') as well?
    def filter_mode = shared.name != 'NO_FILE' ? "--filter_IDs <(awk '(\$6 == 0) {print \$7}' <(zcat $shared))" : ''
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    """
    export POLARS_MAX_THREADS=$task.cpus

    pgscatalog-matchmerge \
        $args \
        --dataset $meta.id \
        --scorefile $scorefile \
        --matches *.ipc.zst \
        --min_overlap $params.min_overlap \
        $ambig \
        $multi \
        $filter_mode \
        --outdir \$PWD \
        $split_output \
        $combined_output \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog.match: \$(echo \$(python -c 'import pgscatalog.match; print(pgscatalog.match.__version__)'))
    END_VERSIONS
    """
}
