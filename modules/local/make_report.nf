process MAKE_REPORT {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::r-tidyverse=1.3.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bioconductor-biocworkflowtools:1.20.0--r41hdfd78af_0' :
        'quay.io/biocontainers/bioconductor-biocworkflowtools:1.20.0--r41hdfd78af_0' }"

    input:
    path scorefiles
    path report
    path logo

    output:
    path "*.html"      , emit: report
    path "*.txt"       , emit: scores
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    # dumb workaround symlink & out_dir (rmarkdown)
    cp $report report.rmd

    R -e 'rmarkdown::render("report.rmd", \
        output_options = list(self_contained=TRUE))'

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
