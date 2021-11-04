// inspired by sra_fastq_ftp.nf in nf-core/fetchngs
// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PGSCATALOG_PARSE {
    label 'process_low'
    label 'error_retry'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::jq=1.6" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/jq:1.6"
    } else {
        container "quay.io/biocontainers/jq:1.6"
    }

    input:
    tuple val(accession), path(json)

    output:
    tuple val(accession), path("*.txt"), emit: url
    path "versions.yml"                , emit: versions

    script:
    """
    jq '[.ftp_scoring_file] | @tsv' ${json} > ${accession}.txt

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        jq: \$(jq --version 2>&1 | sed 's/jq-//')
    END_VERSIONS
    """
}
