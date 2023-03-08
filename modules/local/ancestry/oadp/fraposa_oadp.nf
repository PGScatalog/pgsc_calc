process FRAPOSA_OADP {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'fraposa' // controls conda, docker, + singularity options

    tag "$meta.id"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(ref_geno), path(ref_pheno), path(ref_variants),
        path(target_geno), path(target_pheno), path(target_variants)

    output:
    tuple path("*.pcs"), emit: pcs
    path "versions.yml", emit: versions

    script:
    """
    fraposa ${ref_geno.baseName} \
        --method oadp \
        --dim_ref 10 \
        --stu_filepref ${target_geno.baseName}

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        fraposa: TODO
    END_VERSIONS
    """
}
