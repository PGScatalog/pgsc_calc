// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process VALIDATE_EXTRACT {
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/mawk:1.3.4--h779adbc_4"
    } else {
        container "quay.io/biocontainers/mawk:1.3.4--h779adbc_4"
    }

    input:
    path(extracted)
    path(variants)
    path(awk_file)

    output:
    path "scorefile.txt", emit: scorefile
    path "extract.log"  , emit: log
    path "versions.yml" , emit: versions

    script:
    def softwareName = "mawk"
    """
    mawk \
        ${options.args} \
        -f ${awk_file} \
        ${extracted} \
        ${variants}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${softwareName}: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
