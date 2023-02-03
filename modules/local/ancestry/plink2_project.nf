process PLINK2_PROJECT {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(eigenvec), path(afreq)

    output:
    tuple val(meta), path("*_proj.sscore"), emit: projections
    path "*.sscore.vars", emit: vars_projected
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'
    def mem_mb = task.memory.toMega() // plink is greedy
    """
    plink2 $input ${geno.simpleName} \
        --threads $task.cpus \
        --memory $mem_mb \
        $args \
        --read-freq $afreq \
        --score $eigenvec 2 4 header-read variance-standardize cols=-scoreavgs,+scoresums list-variants \
        --score-col-nums 5-24 \
        --out ${geno.simpleName}_proj

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
