process SAMPLESHEET_JSON {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'pgscatalog_utils' // controls conda, docker, + singularity options

    tag "$samplesheet"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.version}" :
        "${task.ext.docker}${task.ext.version}" }"

    input:
    path samplesheet

    output:
    path "out.json"    , emit: json
    path "versions.yml", emit: versions

    script:
    """
    samplesheet_to_json.py $samplesheet out.json

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python --version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
