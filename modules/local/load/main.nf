process PGSC_CALC_LOAD {
    label 'process_single'
    tag "${meta}"

    container 'pgscatalog/pgsc_calc:v3-alpha.2'

    input:
    tuple val(meta), path(target_genome, arity: '1'), path(bgen_sample_file, arity: '1'), path(target_index, arity: '1')
    path scorefiles, arity: '1.*'
    path zarr_zip, arity: '1'
    val variant_batch_size // int > 1
    path sex_map

    output:
    tuple val(meta), path("cache"), emit: loaded
    path "sex_check.tsv", emit: sex_check, optional: true
    path "versions.yml", emit: "versions"

    script:
    def annotated_target_path = meta.chrom != 'ALL' ? "${target_genome}:${meta.chrom}": "${target_genome}"
    def bgen_sample_arg = bgen_sample_file.name != 'BGEN_SAMPLE_NO_FILE' ? "--bgen_sample_file $bgen_sample_file" : ''
    def zarr_zip_arg = zarr_zip.name != 'ZARR_ZIP_NO_FILE' ? "--zarr_zip_file $zarr_zip" : ""
    def sex_arg = sex_map.name != 'SEX_MAP_NO_FILE' ? "--sex_map $sex_map" : ''
    """
    mkdir cache

    pgsc_calc load \
      --target_genomes $annotated_target_path \
      --score_paths $scorefiles \
      --sampleset $meta.sampleset \
      --format $meta.file_format \
      --cache_dir cache \
      --absence_semantics $meta.absent_variants \
      $sex_arg \
      $bgen_sample_arg \
      $zarr_zip_arg \
      --threads $task.cpus \
      --batch_size $variant_batch_size \
      --verbose

    if [ -f cache/sex_check.tsv ]; then cp cache/sex_check.tsv sex_check.tsv; fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """

}
