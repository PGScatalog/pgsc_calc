process PGSC_CALC_SCORE_COMBINE {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    input:
    path(partials, stageAs: 'partials??/*')
    output:
    path 'out/scores.txt.gz', emit: scores
    path 'versions.yml', emit: versions
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc combine --partial_scores partials*/*.parquet \
      --threads $task.cpus --max_memory_gb $memory --out_dir out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)')
    END_VERSIONS
    """
}
