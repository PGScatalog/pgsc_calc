process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5 sqlite" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    tuple val(meta), val(chrom), path('??.vars'), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "match_variants.db"                 , emit: db
    path "report.csv"                        , emit: log
    path "versions.yml"                      , emit: versions

    script:
    def args = task.ext.args ?: ''
    def split = !chrom.contains(false) ? '--split': ''
    def format = meta.is_bfile ? 'bim' : 'pvar'
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    """
    match_variants.py \
        $args \
        --dataset ${meta.id} \
        --scorefile $scorefile \
        --target '*.vars' \
        $split \
        $format

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
        sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
    END_VERSIONS
    """
}
