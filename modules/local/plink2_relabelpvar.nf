process PLINK2_RELABELPVAR {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/plink2:2.00a2.3--h712d239_1' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:2.00a2.3--h712d239_1' }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants)

    output:
    tuple val(meta), path("*.pgen"), emit: geno
    tuple val(meta), path("*.pvar"), emit: variants
    tuple val(meta), path("*.psam"), emit: pheno
    path "versions.yml"            , emit: versions

    when:
    // only execute when pfile because output format is different (bim vs pvar)
    meta.is_pfile

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
        --pfile ${geno.baseName} \\
        --make-just-pvar \\
        --out ${prefix}_${meta.chrom}

    cp -P $geno ${prefix}_${meta.chrom}.pgen
    cp -P $pheno ${prefix}_${meta.chrom}.psam

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
