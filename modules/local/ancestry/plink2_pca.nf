process PLINK2_PCA {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'plink2' // controls conda, docker, + singularity options

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(pruned)

    output:
    tuple val(meta), path("*.afreq"), emit: afreq
    tuple val(meta), path("*.eigenvec.var"), emit: eigenvec_var
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    """
    # derive PCA on _reference_ population
    plink2 \
        --threads $task.cpus \
        --memory $mem_mb \
        --pfile vzs ${geno.simpleName} \
        --extract $pruned \
        --freq \
        --pca biallelic-var-wts 20 \
        --out ${geno.simpleName}_pcs_ref

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
