process SCOREFILE_CHECK {
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5 bioconda::pyliftover=0.4" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-afe3324bf2effca1c6ea39313147c33dd2c3686e:20ba75f8224cb981ed077e2d6a4d0bdf96a5bf2d-0' :
        'quay.io/biocontainers/mulled-v2-afe3324bf2effca1c6ea39313147c33dd2c3686e:20ba75f8224cb981ed077e2d6a4d0bdf96a5bf2d-0' }"

    input:
    path raw_scores

    output:
    path "scorefiles.pkl", emit: scorefiles
    path "versions.yml"  , emit: versions

    script:
    def args = task.ext.args ?: ''

    if (params.liftover)
        """
        read_scorefile.py -s $raw_scores \
            --liftover \
            -t $params.target_build \
            -o scorefiles.pkl \
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
            -o scorefiles.pkl

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            python: \$(echo \$(python --version 2>&1) | cut -f 2 -d ' ')
            pandas: \$(echo \$(python -c 'import pandas as pd; print(pd.__version__)'))
            pyliftover: \$(echo \$(python -c 'import pyliftover; print(pyliftover.__version__)'))
        END_VERSIONS
        """
}
