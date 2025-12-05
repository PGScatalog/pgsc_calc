process PGSC_CALC_REPORT {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://ghcr.io/pgscatalog/report:2-beta-singularity'
        : 'ghcr.io/pgscatalog/report:2-beta'}"

    input:
    val(sampleset)
    path "scores.txt.gz", arity: '1'
    path "log_scorefiles.json", arity: '1'
    path "match_summary.txt", arity: '1'
    tuple val(keep_multiallelic), val(keep_ambiguous), val(min_overlap) // bool, bool, float
    path(report_path, arity: '4') // 4 files expected: report, css, background image x2

    output:
    path "report.html", arity: '1', emit: report
    path "versions.yml", arity: '1', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    export TMPDIR=\$PWD # tmpdir must always be writable for quarto
    echo $workflow.commandLine > command.txt

    echo "keep_multiallelic: $keep_multiallelic" > params.txt
    echo "keep_ambiguous   : $keep_ambiguous"    >> params.txt
    echo "min_overlap      : $min_overlap"       >> params.txt

    quarto render report.qmd -M "self-contained:true" \
        -P score_path:"scores.txt.gz" \
        -P sampleset:$sampleset \
        -P version:$workflow.manifest.version \
        -o report.html

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """

    stub:
    """
    touch report.html

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        R: \$(echo \$(R --version 2>&1) | head -n 1 | cut -f 3 -d ' ')
    END_VERSIONS
    """
}