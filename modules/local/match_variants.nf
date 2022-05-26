process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "$projectDir/environments/polars/environment.yml" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/polars:0.13.5' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/polars:0.13.5' }"

    input:
    tuple val(meta), val(chrom), path('??.vars'), path(scorefile), path(db)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "log.csv"                           , emit: db
    path "versions.yml"                      , emit: versions

    script:
    def args = task.ext.args ?: ''
    def split = !chrom.contains(false) ? '--split': ''
    def format = meta.is_bfile ? 'bim' : 'pvar'
    def ambig = params.keep_ambiguous ? '--keep_ambiguous' : ''
    def multi = params.keep_multiallelic ? '--keep_multiallelic' : ''
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    """
    match_variants.py \
        $args \
        --dataset ${meta.id} \
        --scorefile $scorefile \
        --target '*.vars' \
        $split \
        --format $format \
        --db \$(readlink -f $db) \
        $ambig \
        $multi

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
        sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
    END_VERSIONS
    """
}
