process INTERSECT_VARIANTS {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"
    storeDir "$workDir/intersected/$meta.id/$meta.chrom"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(vmiss),
        path(ref_geno), path(ref_pheno), path(ref_variants)

    output:
    tuple val(id), path("${meta.id}_${meta.chrom}_matched.txt.gz"), emit: intersection
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    def file_format = meta.is_pfile ? 'pvar' : 'bim'
    id = meta.subMap('id', 'build', 'n_chrom')
    """
    intersect_variants.sh <(plink2 --zst-decompress $ref_variants) \
        <(plink2 --zst-decompress $variants) \
        $file_format $meta.chrom

    mv matched_variants.txt ${meta.id}_${meta.chrom}_matched.txt
    gzip *.txt

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
