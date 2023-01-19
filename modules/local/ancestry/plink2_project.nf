process PLINK2_PROJECT {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(afreq), path(eigenvec)

    output:
    tuple val(meta), path("*_proj.sscore"), emit: projections
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'
    def mem_mb = task.memory.toMega() // plink is greedy
    """
    plink2 $input ${geno.simpleName} \
        --threads $task.cpus \
        --memory $mem_mb \
        $args \
        --read-freq $afreq \
        --score $eigenvec 2 4 header-read variance-standardize cols=-scoreavgs,+scoresums \
        --score-col-nums 5-14 \
        --out ${geno.simpleName}_proj

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
