process SETUP_RESOURCE {
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
    tuple val(meta), path(pgen), path(psam), path(pvar)

    output:
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst"), emit: plink

    """
    # standardise plink prefix on pgen
    mv $psam ${pgen.simpleName}.psam
    plink2 --zst-decompress $pgen > ${pgen.simpleName}.pgen
    mv $pvar ${pgen.simpleName}.pvar.zst
    """
}
