process SCORE_REPORT {
    // first elemenet of tag must be sampleset
    tag "$meta.id" 

    label 'process_high_memory'
    label 'report'

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(scorefile), path(score_log), path(match_summary), path(ancestry)

    output:
    // includeInputs to correctly use $meta.id in publishDir path
    // ancestry results are optional also
    path "*.txt.gz", includeInputs: true
    path "*.json.gz", includeInputs: true, optional: true
    // normal outputs
    path "*.html", emit: report
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    run_ancestry = params.run_ancestry ? true : false
    """
    echo $workflow.commandLine > command.txt
    echo "keep_multiallelic: $params.keep_multiallelic" > params.txt
    echo "keep_ambiguous   : $params.keep_ambiguous"    >> params.txt
    echo "min_overlap      : $params.min_overlap"       >> params.txt

    cp -r $projectDir/assets/report/* .
    # workaround for unhelpful filenotfound quarto errors in some HPCs
    mkdir temp && TMPDIR=temp
    quarto render report.qmd -M "self-contained:true" \
        -P score_path:$scorefile \
        -P sampleset:$meta.id \
        -P run_ancestry:$run_ancestry

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}
