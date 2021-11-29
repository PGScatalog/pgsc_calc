// Import generic module functions
include { initOptions; saveFiles; getSoftwareName; getProcessName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PLINK2_SCORE {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1"
    } else {
        container "quay.io/biocontainers/plink2:2.00a2.3--h712d239_1"
    }

    input:
    tuple val(meta), path(pgen), path(psam), path(pvar), val(scoremeta), path(scorefile), val(n_samples)

    output:
    tuple val(meta), path("*.sscore"), emit: score
    path "versions.yml"              , emit: versions

    script:
    def prefix = options.suffix ? "${meta.id}${options.suffix}" : "${meta.id}"

    if (n_samples < 50)
        """
        plink2 \\
            --score ${scorefile} no-mean-imputation \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (n_samples > 50)
        """
        plink2 \\
            --score ${scorefile} \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}

        cat <<-END_VERSIONS > versions.yml
        ${getProcessName(task.process)}:
            ${getSoftwareName(task.process)}: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
}
