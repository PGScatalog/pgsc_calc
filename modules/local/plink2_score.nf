process PLINK2_SCORE {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1' :
        'quay.io/biocontainers/plink2:2.00a2.3--h712d239_1' }"

    input:
    tuple val(meta), path(pgen), path(psam), path(pvar), val(scoremeta), path(scorefile), val(n_samples)

    output:
    path "*.sscore"    , emit: scores
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''

    if (n_samples < 50)
        """
        colmax=\$(head -n 1 $scorefile | awk -F '\t' '{ print NF }')
        plink2 \\
            --score ${scorefile} header-read cols=scoresums no-mean-imputation $args \\
            --score-col-nums 3-\$colmax \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (n_samples > 50)
        """
        colmax=\$(head -n 1 $scorefile | awk -F '\t' '{ print NF }')
        plink2 \\
            --score ${scorefile} header-read cols=scoresums $args \\
            --score-col-nums 3-\$colmax \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
}
