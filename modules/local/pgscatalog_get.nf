// inspired by sra_fastq_ftp.nf in nf-core/fetchngs
// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PGSCATALOG_GET {
    label 'process_low'
    label 'error_retry'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "conda-forge::curl=7.79.1" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img"
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv1" // vanilla biocontainer
    }

    input:
    tuple val(accession), path(url)

    output:
    path("*.gz"), emit: scorefile
    path "versions.yml"                , emit: versions

    script:
    """
    sed -i '1s/^/url = /' ${url}
    curl -q -O -K ${url}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        curl: \$(curl --version 2>&1 | head -n 1 | sed 's/curl //; s/ (x86.*\$//')
    END_VERSIONS
    """
}
