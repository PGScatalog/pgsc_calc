process SCOREFILE_CHECK {
    label 'process_medium'
    label 'verbose'

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.1.0' :
        dockerimg }"

    input:
    path raw_scores
    path reference

    output:
    path "scorefiles.txt"   , emit: scorefiles
    path "read_scorefile.db", emit: log
    path "versions.yml"     , emit: versions

    script:
    def args = task.ext.args ?: ''

    if (params.liftover)
        """
        # extract chain files from database
        sqlite3 pgsc_calc_ref.sqlar -Ax hg19ToHg38.over.chain.gz hg38ToHg19.over.chain.gz

        read_scorefile.py -s $raw_scores \
            --liftover \
            -t $params.target_build \
            -o scorefiles.txt \
            -m $params.min_lift \
            $args

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            python: \$(echo \$(python --version 2>&1) | cut -f 2 -d ' ')
            pandas: \$(echo \$(python -c 'import pandas as pd; print(pd.__version__)'))
            pyliftover: \$(echo \$(python -c 'import pyliftover; print(pyliftover.__version__)'))
        END_VERSIONS
        """
    else
        """
        read_scorefile.py -s $raw_scores \
            -o scorefiles.txt

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            python: \$(echo \$(python --version 2>&1) | cut -f 2 -d ' ')
            pandas: \$(echo \$(python -c 'import pandas as pd; print(pd.__version__)'))
            pyliftover: \$(echo \$(python -c 'import pyliftover; print(pyliftover.__version__)'))
        END_VERSIONS
        """
}
