process INTERSECT_VARIANTS {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'zstd' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"
    storeDir "$workDir/intersected/$meta.id/$meta.chrom"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(vmiss),
        path(ref_geno), path(ref_pheno), path(ref_variants)

    output:
    tuple val(id), path("${meta.id}_${meta.chrom}_matched.txt.gz"), emit: intersection
    path "intersect_counts_*.txt", emit: intersect_count
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    def file_format = meta.is_pfile ? 'pvar' : 'bim'
    id = meta.subMap('id', 'build', 'n_chrom', 'chrom')
    """
    intersect_variants.sh <(zstdcat $ref_variants) \
        <(zstdcat $variants) \
        $file_format $meta.chrom

    if [ \$(wc -l < matched_variants.txt) -eq 1 ]
    then
        echo "ERROR: No variants in intersection"
        exit 1
    else
        mv matched_variants.txt ${meta.id}_${meta.chrom}_matched.txt
        gzip *_variants.txt *_matched.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        zstd: \$(zstd -V | grep -Eo 'v[0-9]\\.[0-9]\\.[0-9]+' )
    END_VERSIONS
    """
}
