process DOWNLOAD_SCOREFILES {
    tag "$accession"
    time '5m'

    conda (params.enable_conda ? "$projectDir/environments/polars/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.1.0' :
        dockerimg }"

    input:
    val(accession)

    output:
    tuple val(accession), path("PGS*.txt.gz"), emit: scorefiles
    path "versions.yml"                      , emit: versions
    path "PGS*.txt.gz" // for publishDir

    script:
    """
    download_scorefiles -i $accession -o \$PWD -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        jq: \$(jq --version 2>&1 | sed 's/jq-//')
    END_VERSIONS
    """
}
