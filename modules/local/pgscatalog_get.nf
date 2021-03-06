process PGSCATALOG_GET {
    tag "$accession"
    label 'error_retry'

    conda (params.enable_conda ? "bioconda::fastq-scan=1.0.0" : null)
        container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/fastq-scan:1.0.0--h7d875b9_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/fastq-scan:1.0.0--h7d875b9_0' }"

    input:
    val(accession)

    output:
    tuple val(accession), path("PGS*.txt.gz"), emit: scorefiles
    path "versions.yml"                      , emit: versions
    path "PGS*.txt.gz" // for publishDir

    script:
    """
    pgs_api=\$(printf 'http://www.pgscatalog.org/rest/score/search?pgs_ids=%s' ${accession})
    wget \$pgs_api -O response.json

    # check for a valid response. empty response: {} = 2 chars
    if [ \$(jq .size < response.json) -eq 0 ]
    then
        echo "PGS Catalog API error. Is --accession valid?"
        exit 1
    fi

    jq '[.results][][].ftp_scoring_file' response.json | sed 's/https:\\/\\///' > urls.txt

    cat urls.txt | xargs -n 1 wget -T 5

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        jq: \$(jq --version 2>&1 | sed 's/jq-//')
    END_VERSIONS
    """
}
