process PGSC_CALC_DOWNLOAD {
    tag "$meta"
    time '30m'
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container 'pgscatalog/pgsc_calc:v3-alpha.2'

    input:
    val(meta)
    val(build)

    output:
    path("PGS*.txt.gz") , arity: '1..*', emit: scorefiles
    path("versions.yml"), emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def accession_args = meta.pgs_id   ? "-i $meta.pgs_id"  : ""
    def traits_args = meta.efo_id   ? "-t $meta.efo_id"  : ""
    def publication_args = meta.pgp_id ? "-p $meta.pgp_id": ""
    def efo_direct = params.efo_direct ? '-e' : ''

    """
    pgsc_calc download $accession_args \
        $traits_args \
        $publication_args \
        $efo_direct \
        -b $build \
        -o \$PWD \
        -v \
        -c pgsc_calc/$workflow.manifest.version

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
    END_VERSIONS
    """

    stub:
    """
    touch PGS001229_hmPOS_GRCh37.txt.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.core: \$(echo \$(python -c 'import pgscatalog.core; print(pgscatalog.core.__version__)'))
    END_VERSIONS
    """
}