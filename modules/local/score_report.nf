process SCORE_REPORT {
    label 'process_high_memory'

    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/report:${params.platform}-2.14"
    conda (params.enable_conda ? "$projectDir/environments/report/environment.yml" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/report:2.14' :
        dockerimg }"

    input:
    path scorefiles
    path report
    path logo
    path '*' // list of summary csvs, staged with original names

    output:
    path "*.html"      , emit: report
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    cp -LR $report real_report.Rmd
    mv real_report.Rmd report.Rmd

    echo $workflow.commandLine > command.txt
    echo "keep_multiallelic: $params.keep_multiallelic" > params.txt
    echo "keep_ambiguous   : $params.keep_ambiguous"    >> params.txt
    echo "min_overlap      : $params.min_overlap"       >> params.txt

    R -e 'rmarkdown::render("report.Rmd", \
        output_options = list(self_contained=TRUE))'

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
