process PGSC_CALC_CACHE_PACK {
    label 'process_single'
    container 'pgscatalog/pgsc_calc:v3-alpha.2'
    input:
    path(caches, stageAs: 'caches??/*')
    output:
    path 'genotypes.zarr.zip', emit: cache
    script:
    """
    python $projectDir/bin/pack_cache.py genotypes.zarr.zip caches*/*.zip
    """
}
