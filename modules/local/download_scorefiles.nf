process DOWNLOAD_SCOREFILES {
    tag "$meta"
    time '30m'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.1.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.1.2' :
        dockerimg }"

    input:
    val(meta)
    val(build)

    output:
    path "PGS*.txt.gz" , emit: scorefiles
    path "versions.yml", emit: versions

    script:
    def accession_args = meta.pgs_id   ? "-i $meta.pgs_id"  : ""
    def traits_args = meta.trait_efo   ? "-t $meta.trait_efo"  : ""
    def publication_args = meta.pgp_id ? "-p $meta.pgp_id": ""

    """
    download_scorefiles $accession_args \
        $traits_args \
        $publication_args \
        -b $build \
        -o \$PWD -v

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
