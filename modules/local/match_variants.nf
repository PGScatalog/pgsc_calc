process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5 sqlite" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    tuple val(meta), path(target), path(scorefile)

    output:
    tuple val(meta), path("*.scorefile"), emit: scorefile
    path "report.csv"                   , emit: log
    path "versions.yml"                 , emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    sed -i '/##/d' $target # delete annoying plink comment lines before combining
    awk 'FNR == 1 && NR != 1 { next } { print }' $target > combined.txt

    match_variants.py \
        $args \
        --scorefile $scorefile \
        --target combined.txt

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
        sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
    END_VERSIONS
    """
}
