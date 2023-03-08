process MAKE_DATABASE {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'zstd' // controls conda, docker, + singularity options

    storeDir "$workDir/reference"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.version}" :
        "${task.ext.docker}${task.ext.version}" }"

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
