process INTERSECT_VARIANTS {
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'pygscatalog' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    cachedir = params.genotypes_cache ? file(params.genotypes_cache) : workDir
    storeDir cachedir / "ancestry" / "intersected"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(vmiss), path(afreq),
        path(ref_geno), path(ref_pheno), path(ref_variants)

    output:
    tuple val(id), path("${output}.txt.gz"), emit: intersection
    path "intersect_counts_${meta.chrom}.txt", emit: intersect_count
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    def file_format = meta.is_pfile ? 'pvar' : 'bim'
    id = meta.subMap('id', 'build', 'n_chrom', 'chrom')
    output = "${meta.id}_${meta.chrom}_matched"
    """
    pgscatalog-intersect --ref $ref_variants \
        --target $variants \
        --chrom $meta.chrom \
        --outdir .

    if [ \$(wc -l < matched_variants.txt) -eq 1 ]
    then
        echo "ERROR: No variants in intersection"
        exit 1
    else
        mv matched_variants.txt ${output}.txt
        gzip *_variants.txt *_matched.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        zstd: \$(zstd -V | grep -Eo 'v[0-9]\\.[0-9]\\.[0-9]+' )
    END_VERSIONS
    """
}
