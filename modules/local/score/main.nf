process PGSC_CALC_SCORE {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'oras://pgscatalog/pgscatalog-calc:0.1.1'
        : 'docker.io/pgscatalog/pgscatalog-calc:0.1.2'}"

    input:
    path "genotypes/zarr_???.zip", arity: '1..*' // renames input zarr files
    path "scorefiles/*"          , arity: '1.*' // put scorefiles in a directory

    output:
    path "scores.txt.gz"         , arity: '1', emit: "scores"
    path "summary.csv"           , arity: '1', emit: "summary_log"
    path "variant_match_logs.zip", arity: '1', emit: "logs"
    path "versions.yml"          , arity: '1', emit: "versions"

    script:
    """
    mkdir out

    pgsc_calc score \
      --zarr_zip_file genotypes/*.zip \
      --score_paths scorefiles/*.txt.gz \
      --threads $task.cpus \
      --out_dir out

    7z a -tzip -mx0 variant_match_logs.zip out/logs/sampleset=*
    mv out/logs/summary.csv .
    mv out/scores.txt.gz .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """

    stub:
    """
    touch scores.txt.gz
    touch variant_match_logs.zip
    touch summary.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pgscatalog.calc: \$(echo \$(python -c 'import pgscatalog.calc; print(pgscatalog.calc.__version__)'))
    END_VERSIONS
    """
}