process ANCESTRY_ANALYSIS {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple path(scores), path(relatedness), path(ref_psam), path(ref_pcs), path('target_pcs/???.pcs')

    output:
    path "*adjusted.txt.gz", emit: results
    path "versions.yml", emit: versions

    script:
    """
    # TODO: dataset label will break.
    # need to rework workflow to split input data by sampleset
    ancestry_analysis -d hgdp \
        -r reference \
        --psam $ref_psam \
        --ref_pcs $ref_pcs \
        --target_pcs target_pcs/*.pcs \
        -x $relatedness \
        -p SuperPop \
        -s $scores \
        -a RandomForest \
        --n_assignment 10 \
        -n empirical mean mean+var \
        --n_normalization 10 \
        --outdir . \
        -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
