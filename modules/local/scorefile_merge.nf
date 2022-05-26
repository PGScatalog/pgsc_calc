process SCOREFILE_MERGE {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    path(scorefiles)

    output:
    path "merged.scorefile", emit: merged_scorefile
    path "versions.yml"    , emit: versions

    script:
    """
    merge_scorefiles.py \
        -s $scorefiles \
        -o merged.scorefile

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
