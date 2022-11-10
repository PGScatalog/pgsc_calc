process MATCH_VARIANTS {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_medium'
    errorStrategy 'finish'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"

    input:
    tuple val(meta), path(pvar), path(scorefile)

    output:
    tuple val(meta), path("*_matches.ipc.zst"), emit: matches, optional: true
    tuple val(scoremeta), path("*.scorefile.gz"), emit: scorefile, optional: true
    path "*_summary.csv", emit: summary, optional: true
    path "*_log.csv.gz", emit: db, optional: true
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args                ?: ''
    def fast = params.fast_match            ? '--fast'              : ''
    def ambig = params.keep_ambiguous       ? '--keep_ambiguous'    : ''
    def multi = params.keep_multiallelic    ? '--keep_multiallelic' : ''
    def chrom = !meta.chrom.contains("ALL") ? "--chrom $meta.chrom" : ''
    def only_match = !meta.chrom.contains("ALL") ? true : false
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    if (only_match)
        """
        export POLARS_MAX_THREADS=$task.cpus

        match_variants \
            $args \
            --dataset ${meta.id} \
            --scorefile $scorefile \
            --target $pvar \
            --only_match \
            $chrom \
            $fast \
            --outdir \$PWD \
            -n $task.cpus \
            -v

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
        END_VERSIONS
        """
    else
        """
        export POLARS_MAX_THREADS=$task.cpus

        match_variants \
            $args \
            --dataset ${meta.id} \
            --scorefile $scorefile \
            --target $pvar \
            --min_overlap $params.min_overlap \
            $ambig \
            $multi \
            $fast \
            --outdir \$PWD \
            -n $task.cpus \
            -v

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
        END_VERSIONS
        """
}
