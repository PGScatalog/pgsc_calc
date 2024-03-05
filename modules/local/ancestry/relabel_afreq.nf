process RELABEL_AFREQ {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    tag "$meta.id $meta.effect_type $target_format"

    basedir = params.genotypes_cache ? file(params.genotypes_cache) : workDir
    storeDir basedir / "ancestry" / "relabel" / "afreq"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(target), path(matched)

    output:
    tuple val(relabel_meta), path("${output}"), emit: relabelled
    path "versions.yml", emit: versions

    script:
    target_format = target.getName().tokenize('.')[1] // test.tar.gz -> tar, test.var -> var
    relabel_meta = meta.plus(['target_format': target_format]) // .plus() returns a new map
    output_mode = "--split --combined" // always output split and combined data to make life easier
    col_from = "ID_TARGET"
    col_to = "ID_REF"
    output = "${meta.id}.${target_format}*"

    if (target_format == "afreq") {
        col_from = "ID_REF"
        col_to = "ID_TARGET"
        output_mode = "--combined"
    }
    """
    relabel_ids --maps $matched \
        --col_from $col_from \
        --col_to $col_to \
        --target_file $target \
        --target_col ID \
        --dataset ${meta.id}.${target_format} \
        --verbose \
        $output_mode

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
