process COMBINE_SCOREFILES {
    label 'process_medium'
    label 'verbose'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.1.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.1.1' :
        dockerimg }"

    input:
    path raw_scores
    path reference

    output:
    path "scorefiles.txt", emit: scorefiles
    path "versions.yml"  , emit: versions

    script:
    def args = task.ext.args ?: ''

    if (params.liftover)
        """
        # extract chain files from database
        sqlite3 pgsc_calc_ref.sqlar -Ax hg19ToHg38.over.chain.gz hg38ToHg19.over.chain.gz

        combine_scorefiles -s $raw_scores \
            --liftover \
            -t $params.target_build \
            -o scorefiles.txt \
            -c \$PWD \
            -m $params.min_lift \
            $args

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
        END_VERSIONS
        """
    else
        """
        combine_scorefiles -s $raw_scores \
            -t $params.target_build \
            -o scorefiles.txt \
            $args

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
        END_VERSIONS
        """
}
