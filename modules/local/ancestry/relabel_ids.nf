process RELABEL_IDS {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    tag "$meta.id $target_format"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(matched), path(target)

    output:
    tuple val(relabel_meta), path("*_${meta.id}*"), emit: relabelled
    path "versions.yml", emit: versions

    script:
    relabel_meta = meta.subMap('id', 'build')  // workaround for .clone() failing on a groupKey
    target_format = target.getExtension()
    relabel_meta.target_format = target_format
    """
    relabel_ids --maps $matched \
        --col_from ID_REF \
        --col_to ID_TARGET \
        --target_file $target \
        --target_col ID \
        --out ${meta.id}.${target.getExtension()} \
        --verbose

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
