process MAKE_DATABASE {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'zstd' // controls conda, docker, + singularity options

    storeDir workDir / "reference"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    path '*'
    tuple val(grch37_king_meta), path(grch37_king)
    tuple val(grch38_king_meta), path(grch38_king)
    path checksums

    output:
    path "pgsc_calc.tar.zst", emit: reference
    path "versions.yml"    , emit: versions

    script:
    """
    md5sum -c $checksums

    echo ${params.ref_format_version} > meta.txt

    # can't use meta variables in stageAs
    # don't want to use renameTo because it's destructive for the input
    cp -L $grch37_king ${grch37_king_meta.build}_${grch37_king_meta.id}.king.cutoff.out.id
    cp -L $grch38_king ${grch38_king_meta.build}_${grch38_king_meta.id}.king.cutoff.out.id
    rm $grch37_king $grch38_king

    tar --dereference -acf pgsc_calc.tar.zst *

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        zstd: \$(zstd --version | cut -d ' ' -f 7 | sed 's/v// ; s/,//'))
    END_VERSIONS
    """
}
