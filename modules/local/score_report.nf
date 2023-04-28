process SCORE_REPORT {
    label 'process_high_memory'
    label 'report'

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    path scorefiles
    path log_scorefiles
    path '*' // list of summary csvs, staged with original names
    path ancestry_results

    output:
    path "*.html"      , emit: report
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    echo $workflow.commandLine > command.txt
    echo "keep_multiallelic: $params.keep_multiallelic" > params.txt
    echo "keep_ambiguous   : $params.keep_ambiguous"    >> params.txt
    echo "min_overlap      : $params.min_overlap"       >> params.txt

    cp -r $projectDir/assets/report/* .
    # workaround for unhelpful filenotfound quarto errors in some HPCs
    mkdir temp && TMPDIR=temp
    quarto render report.qmd -M "self-contained:true"

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
