process SCORE_REPORT {
    // first elemenet of tag must be sampleset
    tag "$meta.id" 

    label 'process_high_memory'
    label 'report'

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(scorefile), path(score_log), path(match_summary), path(ancestry)
    path intersect_count
    val reference_panel_name

    output:
    // includeInputs to correctly use $meta.id in publishDir path
    // ancestry results are optional also
    path "*.txt.gz", includeInputs: true
    path "*.json.gz", includeInputs: true, optional: true
    // for testing ancestry workflow
    path "pop_summary.csv", optional: true
    // normal outputs
    path "*.html", emit: report
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    run_ancestry = params.run_ancestry ? true : false
    """
    cp $projectDir/assets/report/report.qmd .

    echo $workflow.commandLine > command.txt
    echo "keep_multiallelic: $params.keep_multiallelic" > params.txt
    echo "keep_ambiguous   : $params.keep_ambiguous"    >> params.txt
    echo "min_overlap      : $params.min_overlap"       >> params.txt

    export XDG_CACHE_HOME=\$(mktemp -d)
    
    quarto render report.qmd -M "self-contained:true" \
        -P score_path:$scorefile \
        -P sampleset:$meta.id \
        -P run_ancestry:$run_ancestry \
        -P reference_panel_name:$reference_panel_name

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
    // XDG_CACHE_HOME note: https://github.com/quarto-dev/quarto-cli/issues/4594#issuecomment-1619177667
}

