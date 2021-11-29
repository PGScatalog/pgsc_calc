// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MAKE_REPORT {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::mawk=1.3.4" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/bioconductor-biocworkflowtools:1.20.0--r41hdfd78af_0"
    } else {
        container "quay.io/biocontainers/bioconductor-biocworkflowtools:1.20.0--r41hdfd78af_0"
    }

    input:
    tuple val(meta), path('results.scorefile')
    path(report)

    output:
    path "*.html"      , emit: report
    path "versions.yml", emit: versions

    script:
    """
    # dumb workaround symlink & out_dir (rmarkdown)
    # don't want to stageInMode very big score files
    cp $report report.rmd
    R -e 'rmarkdown::render("report.rmd", \
        params = list(file = "results.scorefile"), \
        output_options = list(self_contained=TRUE))'

    cat <<-END_VERSIONS > versions.yml
    ${getProcessName(task.process)}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
