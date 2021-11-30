process SCOREFILE_QC {
    tag "$meta.accession"

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4' :
        'quay.io/biocontainers/mawk:1.3.4--h779adbc_4' }"

    input:
    tuple val(meta), path(datafile)

    output:
    tuple val(meta), path("*.txt"), emit: data
    path "versions.yml"           , emit: versions

    script:
    def prefix  = "${meta.accession}"
    """
    mawk -v out=${prefix}.txt \
        -f ${projectDir}/bin/qc_scorefile.awk \
        ${datafile}

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
