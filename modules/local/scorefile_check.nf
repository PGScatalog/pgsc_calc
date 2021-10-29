// Import generic module functions
include { saveFiles; getProcessName; getSoftwareName } from './functions'

params.options = [:]

process SCOREFILE_CHECK {
    tag "$scorefile"
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
    path scorefile

    output:
    path "*.txt"       , emit: scores
    path "versions.yml", emit: versions
    // specify path with -f manually for portability (mawk can live lots of places)
    // env won't work with parameters too!
    script:
    """
    mawk -v out=output.txt \
        -f ${projectDir}/bin/check_scorefile.awk \
        ${scorefile}

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        ${getSoftwareName(task.process)}: \$(echo \$(mawk -W version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
