process FRAPOSA_PCA {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'fraposa' // controls conda, docker, + singularity options

    tag "reference"
    // permanently derive a PCA for each reference - sampleset combination
    storeDir "${workDir.resolve()}/fraposa/${ref_geno.baseName}/${targetmeta.id}/"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(ref_geno), path(ref_pheno), path(ref_variants)
    tuple val(targetmeta), path(target_geno)

    output:
    path "*.{dat,pcs}", emit: pca
    path "versions.yml", emit: versions

    script:
    """
    fraposa ${ref_geno.baseName} \
        --method $params.projection_method \
        --dim_ref 10

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        fraposa: TODO
    END_VERSIONS
    """
}
