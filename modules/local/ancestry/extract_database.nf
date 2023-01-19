process EXTRACT_DATABASE {
    label 'process_low'

    conda (params.enable_conda ? "$projectDir/environments/zstd/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/zstd:${params.platform}-1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/zstd:amd64-1.5.2' :
        dockerimg }"

    input:
    path reference

    output:
    tuple val(meta38), path("GRCh38_1000G_ALL.pgen"), path("GRCh38_1000G_ALL.psam"), path("GRCh38_1000G_ALL.pvar.zst"), emit: grch38, optional: true
    tuple val(meta38), path("deg2_hg38.king.cutoff.out.id"), emit: grch38_king, optional: true
    tuple val(meta37), path("GRCh37_1000G_ALL.pgen"), path("GRCh37_1000G_ALL.psam"), path("GRCh37_1000G_ALL.pvar.zst"), emit: grch37, optional: true
    tuple val(meta37), path("deg2_phase3.king.cutoff.out.id"), emit: grch37_king, optional: true
    path "versions.yml", emit: versions

    script:
    meta38 = ['build': 'GRCh38']
    meta37 = ['build': 'GRCh37']
    def king = params.target_build == "GRCh37" ? "deg2_phase3.king.cutoff.out.id" : "deg2_hg38.king.cutoff.out.id"

    """
    tar -xvf $reference --wildcards "${params.target_build}*" $king

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
