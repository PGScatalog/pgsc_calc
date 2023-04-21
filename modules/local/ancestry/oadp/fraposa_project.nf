process FRAPOSA_PROJECT {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'fraposa' // controls conda, docker, + singularity options

    tag "${target_geno.baseName.tokenize('_')[1]}"
    storeDir "$workDir/fraposa/${params.target_build}/${target_geno.baseName}"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(ref_geno), path(ref_pheno), path(ref_variants),
        path(target_geno), path(target_pheno), path(target_variants), path(split_fam),
        path(pca)

    output:
    tuple val(oadp_meta), path("GRCh3?_${target_id}_*.pcs"), emit: pca
    path "versions.yml", emit: versions

    script:
    target_id = target_geno.baseName.tokenize('_')[1]
    oadp_meta = ['target_id':target_id]
    """
    fraposa ${ref_geno.baseName} \
        --method $params.projection_method \
        --dim_ref 10 \
        --stu_filepref ${target_geno.baseName} \
        --stu_filt_iid <(cut -f1 $split_fam) \
	--out ${target_geno.baseName}_${split_fam}

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        fraposa: TODO
    END_VERSIONS
    """
}
