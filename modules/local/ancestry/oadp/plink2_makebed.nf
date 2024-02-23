process PLINK2_MAKEBED {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome"
    storeDir "${workDir.resolve()}/ancestry/bed/${geno.baseName}/"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    // input is sorted alphabetically -> bed, fam, bim.zst or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants), path(pruned)

    output:
    tuple val(meta), path("*.bed"), emit: geno
    tuple val(meta), path("*.bim"), emit: variants
    tuple val(meta), path("*.fam"), emit: pheno
    tuple val(meta), path("splitfam*"), emit: splits, optional: true
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // output options
    def extract = pruned.name != 'NO_FILE' ? "--extract $pruned" : ''
    def extracted = pruned.name != 'NO_FILE' ? "_extracted" : ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}_" : "${meta.id}_"

    """
    # use explicit flag because pfile prefix might be different
    plink2 \
        --threads $task.cpus \
        --memory $mem_mb \
        --seed 31 \
        --pgen $geno \
        --psam $pheno \
        --pvar $variants \
        --make-bed \
        $extract \
        --out ${params.target_build}_${prefix}${meta.chrom}${extracted}

    if [ $meta.id != 'reference' ]
    then
        split -l 50000 <(grep -v '#' $pheno) splitfam
    fi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
