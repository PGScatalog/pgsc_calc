process MAKE_DATABASE {
    label 'process_low'
    storeDir "$workDir/reference"

    conda (params.enable_conda ? "$projectDir/environments/pgscatalog_utils/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/pgscatalog_utils:${params.platform}-0.3.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/pgscatalog_utils:amd64-0.3.0' :
        dockerimg }"

    input:
    path '*'

    output:
    path "pgsc_calc.tar.gz", emit: reference
    path "versions.yml"    , emit: versions

    script:
    """
    echo $workflow.start > meta.txt
    echo $workflow.manifest.version > meta.txt

    tar --dereference -czf pgsc_calc.tar.gz *

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        pgscatalog_utils: \$(echo \$(python -c 'import pgscatalog_utils; print(pgscatalog_utils.__version__)'))
    END_VERSIONS
    """
}
