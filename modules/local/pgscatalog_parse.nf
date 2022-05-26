process PGSCATALOG_PARSE {
    tag "$accession"
    label 'process_low'
    label 'error_retry'

    conda (params.enable_conda ? "bioconda::jq=1.6" : null)
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/jq:1.6' :
        'quay.io/biocontainers/jq:1.6' }"

    input:
    tuple val(accession), path(json)

    output:
    tuple val(accession), path("*.txt"), emit: url
    path "versions.yml"                , emit: versions

    script:
    """
    jq '[.ftp_scoring_file] | @tsv' ${json} > ${accession}.txt

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        jq: \$(jq --version 2>&1 | sed 's/jq-//')
    END_VERSIONS
    """
}
