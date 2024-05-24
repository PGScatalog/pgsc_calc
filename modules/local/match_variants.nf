process MATCH_VARIANTS {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    // first element of tag must be sampleset
    tag "$meta.id chromosome $meta.chrom"
    errorStrategy 'finish'

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(pvar), path(scorefile)

    output:
    tuple val(meta), path("*.ipc.zst"), emit: matches
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

    pgscatalog-match \
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
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog.match: \$(echo \$(python -c 'import pgscatalog.match; print(pgscatalog.match.__version__)'))
    END_VERSIONS
    """
}
