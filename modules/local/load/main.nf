process PGSC_CALC_LOAD {
    label 'process_low'
    tag "${meta}"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://pgscatalog/pgscatalog-calc:0.1.1'
        : 'docker.io/pgscatalog/pgscatalog-calc:0.1.2'}"

    input:
    tuple val(meta), path(target_genome, arity: '1'), path(bgen_sample_file, arity: '1'), path(target_index, arity: '1')
    path scorefiles, arity: '1.*'
    path zarr_zip, arity: '1'

    output:
    path "cache/genotypes.zarr.zip", arity: '1', emit: "zarr_zip"
    path "versions.yml", emit: "versions"

    script:
    def annotated_target_path = meta.chrom ? "${target_genome}:${meta.chrom}": "${target_genome}"
    def bgen_sample_arg = bgen_sample_file.name != 'BGEN_SAMPLE_NO_FILE' ? "--bgen_sample_file $bgen_sample_file" : ''
    def zarr_zip_arg = zarr_zip.name != 'ZARR_ZIP_NO_FILE' ? "--zarr_zip_file $zarr_zip" : ""
    """
    mkdir cache

    pgsc_calc load \
      --target_genomes $annotated_target_path \
      --score_paths $scorefiles \
      --sampleset $meta.sampleset \
      --format $meta.file_format \
      --cache_dir cache \
      $bgen_sample_arg \
      $zarr_zip_arg \
      --threads $task.cpus \
      --verbose

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """

    stub:
    """
    mkdir -p cache
    touch cache/genotypes.zarr.zip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """
}