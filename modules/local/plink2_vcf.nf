process PLINK2_VCF {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1' :
        'quay.io/biocontainers/plink2:2.00a2.3--h712d239_1' }"

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(newmeta), path("*.pgen"), emit: pgen
    tuple val(newmeta), path("*.psam"), emit: psam
    tuple val(newmeta), path("*.pvar"), emit: pvar
    path "versions.yml"            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_mb = task.memory.toMega()
    newmeta = meta.clone() // copy hashmap for updating...
    newmeta.is_pfile = true // now it's converted to a pfile :)
    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $args \\
        --vcf $vcf \\
        --make-pgen \\
        --out vcf_${prefix}_${meta.chrom} # 'vcf_' prefix is important

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
