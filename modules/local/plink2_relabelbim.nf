process PLINK2_RELABELBIM {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"
    storeDir ( params.genotypes_cache ? "$params.genotypes_cache/${meta.id}/${params.target_build}/${meta.chrom}" :
              "$workDir/genomes/${meta.id}/${params.target_build}/${meta.chrom}/")

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(variants), path(pheno)

    output:
    tuple val(meta), path("*.bed"), emit: geno
    tuple val(meta), path("*.zst"), emit: variants
    tuple val(meta), path("*.fam"), emit: pheno
    tuple val(meta), path("*.vmiss.gz"), emit: vmiss
    path "versions.yml"           , emit: versions

    when:
    // only execute when bfile because output format is different (bim vs pvar)
    meta.is_bfile

    script:
    def args = task.ext.args ?: ''
    def compressed = variants.getName().endsWith("zst") ? 'vzs' : ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}_" : "${meta.id}_"
    def mem_mb = task.memory.toMega() // plink is greedy
    // if dropping multiallelic variants, set a generic ID that won't match
    def set_ma_missing = params.keep_multiallelic ? '' : '--var-id-multi @:#'

    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        --missing vcols=fmissdosage,fmiss \\
        $args \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        --bfile ${geno.baseName} $compressed \\
        --make-just-bim zs \\
        --out ${params.target_build}_${prefix}${meta.chrom}

    # cross platform (mac, linux) method of preserving symlinks
    cp -a $geno ${params.target_build}_${prefix}${meta.chrom}.bed
    cp -a $pheno ${params.target_build}_${prefix}${meta.chrom}.fam
    gzip *.vmiss

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
