process SETUP_RESOURCE {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(pgen), path(psam), path(pvar)

    output:
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst"), emit: plink
    path "versions.yml", emit: versions

    script:
    """
    # standardise plink prefix on pgen
    mv $psam ${pgen.simpleName}.psam
    # --zst-decompress can't be used with mem / threads flags
    plink2 --zst-decompress $pgen ${pgen.simpleName}.pgen
    mv $pvar ${pgen.simpleName}.pvar.zst

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
