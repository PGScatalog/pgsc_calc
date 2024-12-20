process RELABEL_SCOREFILES {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    tag "reference $meta.effect_type $target_format"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(target), path(matched)

    output:
    tuple val(relabel_meta), path("reference*"), emit: relabelled
    path "versions.yml", emit: versions

    script:
    target_format = target.getName().tokenize('.')[1] // test.tar.gz -> tar, test.var -> var
    relabel_meta = meta.plus(['target_format': target_format]) // .plus() returns a new map
    col_from = "ID_TARGET"
    col_to = "ID_REF"
    output = "${meta.id}.${target_format}*"
    """
    pgscatalog-relabel --maps $matched \
        --col_from $col_from \
        --col_to $col_to \
        --target_file $target \
        --target_col ID \
        --dataset reference \
        --verbose \
        --combined \
        --outdir \$PWD

    # TODO: improve pgscatalog-relabel so you can set output names precisely
    # use some unpleasant sed to keep a consistent naming scheme
    # hgdp_ALL_additive_0.scorefile.gz -> reference_ALL_additive_0.scorefile.gz 
    output=\$(echo $target | sed 's/^[^_]*_/reference_/')

    mv reference_ALL_relabelled.gz \$output

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
    END_VERSIONS
    """
}
