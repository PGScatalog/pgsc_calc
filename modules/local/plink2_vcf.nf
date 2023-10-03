process PLINK2_VCF {
    // labels are defined in conf/modules.config
    label 'process_medium'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    storeDir ( params.genotypes_cache ? "$params.genotypes_cache/${meta.id}/${meta.build}/${meta.chrom}" :
              "$workDir/genomes/${meta.id}/${meta.build}/${meta.chrom}/")

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(newmeta), path("${meta.build}_*.pgen"), emit: pgen
    tuple val(newmeta), path("${meta.build}_*.psam"), emit: psam
    tuple val(newmeta), path("${meta.build}_*.zst") , emit: pvar
    tuple val(newmeta), path("${meta.build}_*.vmiss.gz"), emit: vmiss
    path "versions.yml"            , emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.suffix ? "${meta.id}_${task.ext.suffix}" : "${meta.id}"
    def mem_mb = task.memory.toMega()
    def dosage_options = meta.vcf_import_dosage ? 'dosage=DS' : ''
    // rewriting genotypes, so use --max-alleles instead of using generic ID
    def set_ma_missing = params.keep_multiallelic ? '' : '--max-alleles 2'
    def chrom_filter = meta.chrom == "ALL" ? "--chr 1-22, X, Y, XY" : "--chr ${meta.chrom}" // filter to canonical/stated chromosome
    newmeta = meta.clone() // copy hashmap for updating...
    newmeta.is_pfile = true // now it's converted to a pfile :)

    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        --missing vcols=fmissdosage,fmiss \\
        $args \\
        --vcf $vcf $dosage_options \\
        --allow-extra-chr $chrom_filter \\
        --make-pgen vzs \\
        --out ${meta.build}_${prefix}_${meta.chrom}_vcf

    gzip *.vmiss

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
