process PGSC_CALC_SCORE {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    tag "${meta.sampleset}/${meta.chrom}/${meta.shard}"
    input:
    tuple val(meta), path(cache)
    path table
    path 'scorefiles/*'
    output:
    path 'out/partial_scores.parquet', emit: partials
    path 'versions.yml', emit: versions
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc score --zarr_zip_file '$cache' --match_table '$table' --score_paths scorefiles/* \
      --threads $task.cpus --max_memory_gb $memory --out_dir out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)')
    END_VERSIONS
    """
}
