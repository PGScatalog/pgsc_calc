process SCOREFILE_SPLIT {
    label 'process_low'

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4' :
        'quay.io/biocontainers/mawk:1.3.4--h779adbc_4' }"

    input:
    tuple val(meta), path(scorefile)
    val split_mode

    output:
    tuple val(meta), path("*.keep"), emit: scorefile
    path "versions.yml"            , emit: versions

    script:
    """
    sed -i -e 's/:/\\t/' ${scorefile} > scorefile # fix first column
    mawk -v split_mode=${split_mode} \
        -f ${projectDir}/bin/split_bim.awk \
        $scorefile
    sed -i -e 's/\\t/:/' *.keep # restore first column

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
