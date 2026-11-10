nextflow.enable.dsl=2

// Throwaway prototype: can independent tasks reproduce sampleset-wide scoring?
process LOAD {
    tag "${meta.chrom}/${meta.shard}"
    input:
    tuple val(meta), path(target), path(index)
    path scores
    output:
    tuple val(meta), path('cache/genotypes.zarr.zip')
    script:
    def annotated = meta.chrom == 'ALL' ? target : "${target}:${meta.chrom}"
    """
    pgsc_calc load --target_genomes '$annotated' --format vcf \
      --sampleset '${meta.sampleset}' --score_paths '$scores' \
      --absence_semantics unobserved --threads $task.cpus --cache_dir cache
    """
}

process MATCH {
    tag "$chrom"
    input:
    tuple val(chrom), path(caches, stageAs: 'caches??/*')
    path scores
    output:
    tuple val(chrom), path('out/matches.parquet'), path('out/samples.parquet')
    script:
    def flags = [params.keep_ambiguous ? '--keep_ambiguous' : '',
                 params.keep_multiallelic ? '--keep_multiallelic' : '',
                 params.ignore_strand_flips ? '--ignore_strand_flips' : ''].join(' ')
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc match --zarr_zip_file caches*/*.zip --score_paths '$scores' \
      $flags --threads $task.cpus --max_memory_gb $memory --out_dir out
    """
}

process MATCH_COMBINE {
    publishDir params.outdir, mode: 'copy', pattern: 'logs'
    input:
    path(matches, stageAs: 'matches??/*')
    path(samples, stageAs: 'samples??/*')
    path scores
    val sampleset
    output:
    path 'out/match_table.parquet', emit: table
    path 'logs', emit: logs
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc match-combine --matches matches*/*.parquet --samples samples*/*.parquet \
      --score_paths '$scores' --sampleset '$sampleset' --min_overlap $params.min_overlap \
      --threads $task.cpus --max_memory_gb $memory --out_dir out
    mv out/logs logs
    """
}

process SCORE {
    tag "${meta.chrom}/${meta.shard}"
    input:
    tuple val(meta), path(cache)
    path table
    path scores
    output:
    path 'out/partial_scores.parquet'
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc score --zarr_zip_file '$cache' --match_table '$table' --score_paths '$scores' \
      --threads $task.cpus --max_memory_gb $memory --out_dir out
    """
}

process SCORE_COMBINE {
    publishDir params.outdir, mode: 'copy', saveAs: { it.tokenize('/').last() }
    input:
    path(partials, stageAs: 'partials??/*')
    output:
    path 'out/scores.txt.gz'
    script:
    def memory = Math.max(1, (task.memory.toMega() / 1024.0 * 0.75).intValue())
    """
    pgsc_calc combine --partial_scores partials*/*.parquet \
      --threads $task.cpus --max_memory_gb $memory --out_dir out
    """
}

workflow {
    scores = Channel.value(file(params.scorefile, checkIfExists: true))
    rows = Channel.fromPath(params.input, checkIfExists: true).splitCsv(header: true).collect().map { records ->
        if (!records) error 'The samplesheet is empty'
        def labels = records.collect { it.sampleset }.unique()
        if (labels.size() != 1 || !(labels[0] ==~ /[A-Za-z0-9_-]+/))
            error 'The prototype requires exactly one sampleset with a simple label'
        def leaves = []
        def validated = records.collect { row ->
            if (row.file_format != 'vcf') error 'This prototype currently accepts VCF only'
            if ((row.absent_variants ?: 'unobserved') != 'unobserved')
                error 'Only absent_variants=unobserved is supported'
            def chrom = row.chrom ?: 'ALL'
            if (!(chrom ==~ /([1-9]|1[0-9]|2[0-2]|X|Y|MT|ALL)/))
                error 'Use canonical chromosome names or an empty chromosome for whole-genome input'
            def target = file(row.path, checkIfExists: true)
            def leaf = "${row.sampleset}/${chrom}/${target.name}"
            if (leaf in leaves) error "Duplicate cache leaf: $leaf"
            leaves << leaf
            [[sampleset: row.sampleset, chrom: chrom, shard: target.name], target,
             file("${row.path}.csi", checkIfExists: true)]
        }
        return validated
    }
    shards = rows.flatMap { it }
    sampleset = rows.map { it[0][0].sampleset }
    LOAD(shards, scores)
    MATCH(LOAD.out.map { meta, cache -> [meta.chrom, cache] }.groupTuple(), scores)
    MATCH_COMBINE(MATCH.out.map { chrom, matches, samples -> matches }.collect(),
                  MATCH.out.map { chrom, matches, samples -> samples }.collect(), scores, sampleset)
    SCORE(LOAD.out, MATCH_COMBINE.out.table, scores)
    SCORE_COMBINE(SCORE.out.collect())
}
