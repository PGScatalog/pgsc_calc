process PGSC_CALC_MATCH {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    tag "$chrom"
    input:
    tuple val(chrom), path(caches, stageAs: 'caches??/*')
    path 'scorefiles/*'
    output:
    tuple val(chrom), path('out/matches.parquet'), path('out/samples.parquet'), emit: matches
    path 'versions.yml', emit: versions
    script:
    def flags = [params.keep_ambiguous ? '--keep_ambiguous' : '',
                 params.keep_multiallelic ? '--keep_multiallelic' : '',
                 params.ignore_strand_flips ? '--ignore_strand_flips' : ''].join(' ')
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc match --zarr_zip_file caches*/*.zip --score_paths scorefiles/* \
      $flags --threads $task.cpus --max_memory_gb $memory --out_dir out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)')
    END_VERSIONS
    """
}
