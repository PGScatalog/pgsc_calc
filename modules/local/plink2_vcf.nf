process PLINK2_VCF {
    tag "$meta.id chromosome $meta.chrom"
    storeDir ( params.genotypes_cache ? "$params.genotypes_cache/${meta.id}/${meta.chrom}" :
              "$workDir/genomes/${meta.id}/${meta.chrom}/")
    label 'process_medium'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(newmeta), path("*.pgen"), emit: pgen
    tuple val(newmeta), path("*.psam"), emit: psam
    tuple val(newmeta), path("*.zst") , emit: pvar
    path "versions.yml"            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_mb = task.memory.toMega()
    // rewriting genotypes, so use --max-alleles instead of using generic ID
    def set_ma_missing = params.keep_multiallelic ? '' : '--max-alleles 2'
    newmeta = meta.clone() // copy hashmap for updating...
    newmeta.is_pfile = true // now it's converted to a pfile :)

    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        $args \\
        --vcf $vcf \\
        --make-pgen vzs \\
        --out vcf_${prefix}_${meta.chrom} # 'vcf_' prefix is important

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
