process PLINK2_SCORE {
    errorStrategy 'finish'
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom effect type $scoremeta.effect_type $scoremeta.n"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), val(scoremeta), path(scorefile)

    output:
    path "*.{sscore,sscore.zst}", emit: scores  // optional compression
    path "*.sscore.vars", emit: vars_scored
    path "versions.yml", emit: versions
    path "*.log"       , emit: log

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // dynamic input option
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'

    // custom args2
    def maxcol = (scoremeta.n_scores + 2) // id + effect allele = 2 cols
    def no_imputation = (meta.n_samples < 50) ? 'no-mean-imputation' : ''
    def cols = (meta.n_samples < 50) ? 'header-read cols=+scoresums,+denom,-fid' : 'header-read cols=+scoresums,+denom,-fid'
    def recessive = (scoremeta.effect_type == 'recessive') ? ' recessive ' : ''
    def dominant = (scoremeta.effect_type == 'dominant') ? ' dominant ' : ''

    args2 = [args2, cols, 'list-variants', no_imputation, recessive, dominant].join(' ')

    if (scoremeta.n_scores == 1)
        """
        plink2 \\
            --threads $task.cpus \\
            --memory $mem_mb \\
            --seed 31 \\
            $args \\
            --score $scorefile $args2 \\
            $input ${geno.baseName} \\
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (scoremeta.n_scores > 1)
        """
        plink2 \\
            --threads $task.cpus \\
            --memory $mem_mb \\
            --seed 31 \\
            $args \\
            --score $scorefile $args2 \\
            --score-col-nums 3-$maxcol \\
            $input ${geno.baseName} \\
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
}
