process SCOREFILE_CHECK {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    path raw_scores

    output:
    path "scorefiles.pkl", emit: scorefiles
    path "versions.yml"  , emit: versions

    script:
    """
    read_scorefile.py -s $raw_scores -o scorefiles.pkl

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python --version 2>&1) | cut -f 2 -d ' ')
    END_VERSIONS
    """
}
