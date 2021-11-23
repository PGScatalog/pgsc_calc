// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:'pipeline_info', meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "conda-forge::curl=7.79.1" : null) // dummy conda
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://containers.biocontainers.pro/s3/SingImgsRepo/biocontainers/v1.2.0_cv1/biocontainers_v1.2.0_cv1.img"
    } else {
        container "biocontainers/biocontainers:v1.2.0_cv1" // vanilla biocontainer
    }

    input:
    tuple val(meta), path(target), val(scoremeta), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "*.log"                             , emit: log
//    path "versions.yml"                      , emit: versions

    script:
    """
    mawk -f $projectDir/bin/match_variants.awk \
        $options.args \
        -v target=$target \
        -v mem=\$(echo $task.memory | sed 's/ //; s/B//') \
        -v cpu=$task.cpus \
        $scorefile \
        matched.scorefile.tmp \
        flipped.matched.scorefile.tmp
    """
}
