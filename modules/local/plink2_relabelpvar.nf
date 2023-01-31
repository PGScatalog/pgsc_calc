process PLINK2_RELABELPVAR {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    storeDir ( params.genotypes_cache ? "$params.genotypes_cache/${meta.id}/${meta.build}/${meta.chrom}" :
              "$workDir/genomes/${meta.id}/${meta.build}/${meta.chrom}/")

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants)

    output:
    tuple val(meta), path("*.pgen"), emit: geno
    tuple val(meta), path("*.zst") , emit: variants
    tuple val(meta), path("*.psam"), emit: pheno
    tuple val(meta), path("*.vmiss.gz"), emit: vmiss
    path "versions.yml"            , emit: versions

    when:
    // only execute when pfile because output format is different (bim vs pvar)
    meta.is_pfile

    script:
    def args = task.ext.args ?: ''
    def compressed = variants.getName().endsWith("zst") ? 'vzs' : ''
    def prefix = task.ext.suffix ? "${meta.id}_${task.ext.suffix}_" : "${meta.id}_"
    def build = meta.build? meta.build + '_': ''  // important for making reference
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
        --pfile ${geno.baseName} $compressed \\
        --make-just-pvar zs \\
        --out ${build}${prefix}${meta.chrom}

    cp -RP $geno ${build}${prefix}${meta.chrom}.pgen
    cp -RP $pheno ${build}${prefix}${meta.chrom}.psam
    gzip *.vmiss

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
