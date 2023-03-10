process PLINK2_MAKEBED {
    // labels are defined in conf/modules.config
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"
    label "plink2" // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

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
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // output options
    def extract = pruned.name != 'NO_FILE' ? "--extract $pruned" : ''
    def extracted = pruned.name != 'NO_FILE' ? "_extracted" : ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}_" : "${meta.id}_"
    def build = meta.build? meta.build + '_': ''

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
        --out ${build}${prefix}${meta.chrom}${extracted}

    if [ $meta.id != 'reference' ]
    then
        # split into 50,000 sample chunks
        split -l 50000 -a 4 $pheno split_${prefix}
        for x in split_${prefix}*
        do
            cut -f1,2 \$x > current_ids.txt
            plink2 \
                --threads $task.cpus \
                --memory $mem_mb \
                --seed 31 \
                --bfile ${build}${prefix}${meta.chrom}${extracted} \
                --keep current_ids.txt \
                --keep-allele-order \
                --make-bed \
                --out \$x
        done
        # clean up extracted data
        rm ${build}${prefix}${meta.chrom}${extracted}.bed
        rm ${build}${prefix}${meta.chrom}${extracted}.bim
        rm ${build}${prefix}${meta.chrom}${extracted}.fam
    fi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
