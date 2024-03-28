process PLINK2_RELABELPVAR {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    cachedir = params.genotypes_cache ? file(params.genotypes_cache) : workDir
    storeDir cachedir / "genomes" / "relabelled"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants)

    output:
    tuple val(meta), path("${output}.pgen"), emit: geno
    tuple val(meta), path("${output}.pvar.zst") , emit: variants
    tuple val(meta), path("${output}.psam"), emit: pheno
    tuple val(meta), path("${output}.vmiss.gz"), emit: vmiss
    tuple val(meta), path("${output}.afreq.gz"), emit: afreq
    path "versions.yml"            , emit: versions

    when:
    // only execute when pfile because output format is different (bim vs pvar)
    meta.is_pfile

    script:
    def args = task.ext.args ?: ''
    def compressed = variants.getName().endsWith("zst") ? 'vzs' : ''
    def prefix = task.ext.suffix ? "${meta.id}_${task.ext.suffix}" : "${meta.id}"
    def mem_mb = task.memory.toMega() // plink is greedy
    // if dropping multiallelic variants, set a generic ID that won't match
    def set_ma_missing = params.keep_multiallelic ? '' : '--var-id-multi @:#'
    // def limits scope to process block, so don't use it
    output = "${meta.build}_${prefix}_${meta.chrom}"
    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        --freq \\
        --missing vcols=fmissdosage,fmiss \\
        $args \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        --pfile ${geno.baseName} $compressed \\
        --make-just-pvar zs \\
        --out $output

    # cross platform (mac, linux) method of preserving symlinks
    cp -a $geno ${output}.pgen
    cp -a $pheno ${output}.psam
   
    gzip ${output}.vmiss
    gzip ${output}.afreq

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
