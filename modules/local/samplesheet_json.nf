process SAMPLESHEET_JSON {
    tag "$samplesheet"

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.1.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.1.1' :
        dockerimg }"

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
