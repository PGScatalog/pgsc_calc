process PLINK2_SCORE {
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom effect type $scoremeta.effect_type"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), val(scoremeta), path('scorefile???.gz')

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
    def no_imputation = (meta.n_samples < 50) ? 'no-mean-imputation' : ''
    def cols = (meta.n_samples < 50) ? 'header-read cols=+scoresums,+denom,-fid' : 'header-read cols=+scoresums,+denom,-fid'
    def recessive = (scoremeta.effect_type == 'recessive') ? ' recessive ' : ''
    def dominant = (scoremeta.effect_type == 'dominant') ? ' dominant ' : ''

    args2 = [args2, cols, 'list-variants', no_imputation, recessive, dominant].join(' ')


    """
    # loop to make sure that one scoring file is applied to each chromosome
    # at a time (process is I/O bound, other chroms launch as different jobs)
    for file in scorefile*.gz; do
        # id + effect_allele = 2 columns
        n_scores=\$( head -n1 <(gunzip -cf \$file) | awk 'END { print NF-2 }')
        max_col=\$( head -n1 <(gunzip -cf \$file) | awk 'END { print NF }')

        if [ "\$n_scores" -gt 1 ]
        then
            score_range="--score-col-nums 3-\$max_col"
        else
            score_range=""
        fi

        outf=\$(basename \$file .gz)
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --seed 31 \
            $args \
            --score \$file $args2 \
            \$score_range \
            $input ${geno.baseName} \
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_\$outf
    done

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
