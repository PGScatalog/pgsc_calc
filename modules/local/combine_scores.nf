process COMBINE_SCORES {
    label 'process_low'

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4' :
        'quay.io/biocontainers/mawk:1.3.4--h779adbc_4' }"

    input:
    tuple val(meta), path("*.sscore")

    output:
    tuple val(meta), path("*.sscore"), emit: scorefiles
    path "versions.yml"              , emit: versions

    script:
    """
    mawk -f ${projectDir}/bin/combine_scorefile.awk \\
        *.sscore > ${meta.id}_combined.sscore

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
