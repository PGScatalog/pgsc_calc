process PLINK2_ORIENT {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    // input is sorted alphabetically -> bed, fam, bim.zst or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants), path(ref_variants)

    output:
    tuple val(meta), path("*.bed"), emit: geno
    tuple val(meta), path("*.bim"), emit: variants
    tuple val(meta), path("*.fam"), emit: pheno
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // output options
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}_" : "${meta.id}_"

    """
    plink2 \
        --threads $task.cpus \
        --memory $mem_mb \
        --seed 31 \
        --bed $geno \
        --fam $pheno \
        --bim $variants \
        --a1-allele $ref_variants 5 2 \
        --make-bed \
        --out ${params.target_build}_${prefix}${meta.chrom}_oriented

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
