// Import generic module functions
include { saveFiles; getProcessName } from './functions'

params.options = [:]

process SAMPLESHEET_CHECK {
    tag "$samplesheet"
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
    path samplesheet

    output:
    path '*.csv'       , emit: csv
    path "versions.yml", emit: versions

    script:
    """
    mawk \\
        -f ${projectDir}/bin/check_samplesheet.awk \\
        $samplesheet

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        mawk: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
