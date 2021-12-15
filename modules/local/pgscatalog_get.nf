process PGSCATALOG_GET {
    tag "$accession"
    label 'process_low'
    maxRetries 5
    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }

    conda (params.enable_conda ? "conda-forge::curl=7.79.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img' :
        'biocontainers/biocontainers:v1.2.0_cv1' }"

    input:
    tuple val(accession), path(url)

    output:
    tuple val(accession), path("scorefile"), emit: scorefile
    path "versions.yml"                    , emit: versions

    script:
    """
    sed -i '1s/^/url = /' ${url}
    curl --connect-timeout 5 \\
        --speed-time 10 \\
        --speed-limit 1000 \\
         -O -K ${url}
    gunzip -c *.gz > scorefile

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        sed: \$(sed --version 2>&1 | head -n 1 | cut -f 4 -d ' ')
        gzip: \$(gzip --version 2>&1 | head -n 1 | cut -f 2 -d ' ')
        curl: \$(curl --version 2>&1 | head -n 1 | sed 's/curl //; s/ (x86.*\$//')
    END_VERSIONS
    """
}
