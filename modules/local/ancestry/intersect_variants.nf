process INTERSECT_VARIANTS {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_high_memory'
    storeDir "$workDir/intersected/$meta.id/$meta.chrom"

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(vmiss),
        path(ref_geno), path(ref_pheno), path(ref_variants)

    output:
    path("matched_variants.txt.gz"), emit: intersection
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    def file_format = meta.is_pfile ? 'pvar' : 'bim'
    def chrom = "ALL" // ToDo: edit this to specify current chromosome

    """
    intersect_variants.sh <(plink2 --zst-decompress $ref_variants) \
        <(plink2 --zst-decompress $variants) \
        $file_format $chrom

    gzip matched_variants.txt

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
