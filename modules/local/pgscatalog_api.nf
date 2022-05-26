process PGSCATALOG_API {
    tag "$accession"
    label 'process_low'
    label 'error_retry'

    conda (params.enable_conda ? "conda-forge::curl=7.79.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img' :
        'biocontainers/biocontainers:v1.2.0_cv1' }"

    input:
    val(accession)

    output:
    tuple val(accession), path("*.json"), emit: json
    path "versions.yml"                 , emit: versions

    script:
    """
    pgs_api=\$(printf 'https://www.pgscatalog.org/rest/score/%s' ${accession})
    curl -s \$pgs_api -o ${accession}.json

    # check for a valid response. empty response: {} = 2 chars
    if [ \$(wc -m < ${accession}.json) -eq 2 ]
    then
        echo "PGS Catalog API error. Is --accession valid?"
        exit 1
    fi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        curl: \$(curl --version 2>&1 | head -n 1 | sed 's/curl //; s/ (x86.*\$//')
    END_VERSIONS
    """
}
