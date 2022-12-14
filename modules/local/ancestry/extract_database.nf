process EXTRACT_DATABASE {
    label 'process_low'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"


    input:
    path reference

    output:
    tuple val(meta38), path("GRCh38_reference.pgen"), path("GRCh38_reference.psam"), path("GRCh38_reference.pvar.zst"), emit: grch38
    tuple val(meta37), path("GRCh37_reference.pgen"), path("GRCh37_reference.psam"), path("GRCh37_reference.pvar.zst"), emit: grch37
    path "*.chain.gz", emit: chain
    path "versions.yml", emit: versions

    script:
    meta38 = ['build': 'GRCh38']
    meta37 = ['build': 'GRCh37']
    """
    tar -xzf $reference

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
