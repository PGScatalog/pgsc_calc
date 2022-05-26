process PLINK2_SCORE {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2=2.00a2.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1' :
        'quay.io/biocontainers/plink2:2.00a2.3--h712d239_1' }"

    input:
    tuple val(meta), path(pgen), path(psam), path(pvar), val(scoremeta), path(scorefile)

    output:
    path "*.sscore"    , emit: scores
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''

    def maxcol = (scoremeta.n_scores + 2) // id + effect allele = 2 cols
    def no_imputation = (meta.n_samples >= 50) ? '' : ' no-mean-imputation '
    def recessive = (scoremeta.effect_type == 'recessive') ? ' recessive ' : ''
    def dominant = (scoremeta.effect_type == 'dominant') ? ' dominant ' : ''
    args2 = args2 + no_imputation + recessive + dominant

    if (scoremeta.n_scores == 1)
        """
        plink2 \\
            $args \\
            --score $scorefile $args2 \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (scoremeta.n_scores > 1)
        """
        plink2 \\
            $args \\
            --score $scorefile $args2 \\
            --score-col-nums 3-$maxcol \\
            --pfile ${pgen.baseName} \\
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
}
