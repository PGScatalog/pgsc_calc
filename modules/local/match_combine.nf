process MATCH_COMBINE {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    // first element of tag must be sampleset
    tag "$meta.id"
    scratch (workflow.containerEngine == 'singularity' || params.parallel ? true : false)

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
    def split_output = !meta.chrom.contains("ALL") ? '--split' : ''
    // output one (or more) scoring file per sampleset?
    def combined_output = (meta.chrom.contains("ALL") || shared.name != 'NO_FILE') ? '--combined' : ''
    // filter match candidates to intersect with reference:
    // omit multi-allelic variants in reference because these will cause errors with relabelling!...
    // ... unclear whether we should remove them from target with '&& ($9 == 0') as well?
    def filter_mode = shared.name != 'NO_FILE' ? "--filter_IDs <(awk '(\$6 == 0) {print \$7}' <(zcat $shared))" : ''
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
        $split_output \
        $combined_output \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
