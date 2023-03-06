process PLINK2_MAKEBED {
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
    // input is sorted alphabetically -> bed, fam, bim.zst or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants)
    path pruned // optional list of variants to extract

    output:
    tuple val(meta), path("*.bed"), emit: geno
    tuple val(meta), path("*.zst"), emit: variants
    tuple val(meta), path("*.fam"), emit: pheno
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // input options
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'

    // output options
    def extract = pruned.name != 'NO_FILE' ? "--extract $pruned" : ''
    def thinned = pruned.name != 'NO_FILE' ? "_thinned" : ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}_" : "${meta.id}_"
    def build = meta.build? meta.build + '_': ''

    """
    plink2 \
        --threads $task.cpus \
        --memory $mem_mb \
        --seed 31 \
        $args \
        $input ${geno.baseName} \
        --make-bed vzs \
        $extract \
        --out ${build}${prefix}${meta.chrom}${thinned}

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
