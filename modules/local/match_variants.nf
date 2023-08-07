process MATCH_VARIANTS {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    // first element of tag must be sampleset
    tag "$meta.id chromosome $meta.chrom"
    scratch (workflow.containerEngine == 'singularity' || params.parallel ? true : false)
    errorStrategy 'finish'

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(pvar), path(scorefile)

    output:
    tuple val(meta), path("matches/*.ipc.zst"), emit: matches
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args                ?: ''
    def fast = params.fast_match            ? '--fast'              : ''
    def ambig = params.keep_ambiguous       ? '--keep_ambiguous'    : ''
    def multi = params.keep_multiallelic    ? '--keep_multiallelic' : ''
    def match_chrom = meta.chrom.contains("ALL") ? '' : "--chrom $meta.chrom"
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    """
    export POLARS_MAX_THREADS=$task.cpus

    match_variants \
        $args \
        --dataset ${meta.id} \
        --scorefile $scorefile \
        --target $pvar \
        --only_match \
        $match_chrom \
        $ambig \
        $multi \
        $fast \
        --outdir \$PWD \
        -n $task.cpus \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
