process SCORE_REPORT {
    label 'process_high_memory'
    stageInMode 'copy'

    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/report:${params.platform}-2.14"
    conda (params.enable_conda ? "$projectDir/environments/report/environment.yml" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/report:2.14' :
        dockerimg }"

    input:
    path scorefiles
    path report
    path logo
    path db

    output:
    path "*.html"      , emit: report
    path "*.txt.gz"       , emit: scores
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    R -e 'rmarkdown::render("report.Rmd", \
        output_options = list(self_contained=TRUE))'

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
