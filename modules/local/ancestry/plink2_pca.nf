process PLINK2_PCA {
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

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
        --pca biallelic-var-wts \
        --out ${geno.simpleName}_pcs_ref

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
