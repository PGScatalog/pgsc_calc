process PLINK2_RELABELBIM {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1' :
        'quay.io/biocontainers/plink2:2.00a2.3--h712d239_1' }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(variants), path(pheno)

    output:
    tuple val(meta), path("*.bed"), emit: geno
    tuple val(meta), path("*.bim"), emit: variants
    tuple val(meta), path("*.fam"), emit: pheno
    path "versions.yml"           , emit: versions

    when:
    // only execute when bfile because output format is different (bim vs pvar)
    meta.is_bfile

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}" : "${meta.id}"
    def mem_mb = task.memory.toMega() // plink is greedy

    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        $args \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        --bfile ${geno.baseName} \\
        --make-just-bim \\
        --out ${prefix}_${meta.chrom}

    cp -P $geno ${prefix}_${meta.chrom}.bed
    cp -P $pheno ${prefix}_${meta.chrom}.fam

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
