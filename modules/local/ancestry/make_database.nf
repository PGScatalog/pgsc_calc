process MAKE_DATABASE {
    label 'process_low'
    storeDir "$workDir/reference"

    conda (params.enable_conda ? "$projectDir/environments/zstd/environment.yml" : null)
    def dockerimg = "dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/zstd:${params.platform}-1.5.2"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/singularity/zstd:amd64-1.5.2' :
        dockerimg }"

    input:
    path '*'
    path checksums

    output:
    path "pgsc_calc.tar.zst", emit: reference
    path "versions.yml"    , emit: versions

    script:
    """
    md5sum -c $checksums

    echo $workflow.manifest.version > meta.txt

    tar --dereference -acf pgsc_calc.tar.zst *

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        zstd: \$(zstd --version | cut -d ' ' -f 7 | sed 's/v// ; s/,//'))
    END_VERSIONS
    """
}
