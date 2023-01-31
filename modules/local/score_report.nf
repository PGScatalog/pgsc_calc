process SCORE_REPORT {
    label 'process_high_memory'
    label 'report'

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.version}" :
        "${task.ext.docker}${task.ext.version}" }"

    input:
    path scorefiles
    path log_scorefiles
    path report
    path logo
    path '*' // list of summary csvs, staged with original names

    output:
    path "*.html"      , emit: report
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    # R and symlinks don't get along
    cp -LR $report real_report.Rmd
    mv real_report.Rmd report.Rmd
    cp -LR $log_scorefiles log_combined.json


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
