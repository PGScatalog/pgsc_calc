process PGSC_CALC_MATCH_COMBINE {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    input:
    path(matches, stageAs: 'matches??/*')
    path(samples, stageAs: 'samples??/*')
    path 'scorefiles/*'
    val sampleset
    output:
    path 'out/match_table.parquet', emit: table
    path 'summary.csv', emit: summary_log
    path 'variant_match_logs.zip', emit: logs
    path 'versions.yml', emit: versions
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc match-combine --matches matches*/*.parquet --samples samples*/*.parquet \
      --score_paths scorefiles/* --sampleset '$sampleset' --min_overlap $params.min_overlap \
      --threads $task.cpus --max_memory_gb $memory --out_dir out
    7z a -tzip -mx0 variant_match_logs.zip out/logs/sampleset=*
    mv out/logs/summary.csv .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)')
    END_VERSIONS
    """
}
