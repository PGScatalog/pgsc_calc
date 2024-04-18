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
    tuple val(meta), path("${output}.pgen", includeInputs: true), emit: geno
    tuple val(meta), path("${output}.pvar.zst", includeInputs: false) , emit: variants
    tuple val(meta), path("${output}.psam", includeInputs: true), emit: pheno
    tuple val(meta), path("${output}.vmiss.gz"), emit: vmiss
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
        --missing vcols=fmissdosage,fmiss \\
        $args \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        --pfile ${geno.baseName} $compressed \\
        --make-just-pvar zs \\
        --out $output

    # -a: cross platform (mac, linux) method of preserving symlinks
    # || true: if file exists, ignore error, will be handled by includeInputs
    cp -a $geno ${output}.pgen || true
    cp -a $pheno ${output}.psam || true
   
    gzip ${output}.vmiss

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
