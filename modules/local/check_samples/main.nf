process PGSC_CALC_CHECK_SAMPLES {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    input:
    path(caches, stageAs: 'shards??/*')
    output:
    path 'validated.txt', emit: validated
    script:
    """
    python $projectDir/bin/check_samples.py shards*/cache
    touch validated.txt
    """
}
