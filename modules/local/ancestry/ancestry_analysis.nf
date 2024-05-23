process ANCESTRY_ANALYSIS {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path('target_pcs/???.pcs'), path('ref_pcs/?.pcs'), path(scores), path(relatedness), path(ref_psam)

    output:
    path "*_info.json.gz", emit: info
    path "*_popsimilarity.txt.gz", emit: popsimilarity
    path "*_pgs.txt.gz", emit: pgs
    path "versions.yml", emit: versions

    script:
    """
    pgscatalog-ancestry-adjust -d $meta.target_id \
        -r reference \
        --psam $ref_psam \
        --ref_pcs ref_pcs/1.pcs \
        --target_pcs target_pcs/*.pcs \
        -x $relatedness \
        -p $params.ref_label \
        -s $scores \
        -a $params.ancestry_method \
        --n_popcomp $params.n_popcomp \
        -n $params.normalization_method \
        --n_normalization $params.n_normalization \
        --outdir . \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
