process PLINK2_SCORE {
    errorStrategy 'finish'
    // labels are defined in conf/modules.config
    label 'process_low'
    label 'process_long'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id chromosome $meta.chrom effect type $scoremeta.effect_type $scoremeta.n"

    conda "${task.ext.conda}"

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), val(scoremeta), path(scorefile), path(ref_afreq)

    output:
    tuple val(meta), path("*.{sscore,sscore.zst}"), emit: scores  // optional compression
    path "*.sscore.vars", emit: vars_scored
    path "versions.yml", emit: versions
    path "*.log"       , emit: log

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // dynamic input option
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'

    // load allelic frequencies
    def load_afreq = (ref_afreq.name != 'NO_FILE') ? "--read-freq $ref_afreq" : ""

    // be explicit when comparing ints (use .toInteger()) because:
    //   https://github.com/nextflow-io/nextflow/issues/3952

    // custom args2
    def maxcol = (scoremeta.n_scores.toInteger() + 2) // id + effect allele = 2 cols

    // if we have allelic frequencies or enough samples don't do mean imputation and skip freq-calc
    def no_imputation = ((ref_afreq.name == 'NO_FILE') && (meta.n_samples.toInteger() < 50)) ? "no-mean-imputation" : ""
    def error_on_freq_calc = (no_imputation == "no-mean-imputation") ? "--error-on-freq-calc" : ""

    def cols = 'header-read cols=+scoresums,+denom,-fid'
    def recessive = (scoremeta.effect_type == 'recessive') ? ' recessive ' : ''
    def dominant = (scoremeta.effect_type == 'dominant') ? ' dominant ' : ''
    args2 = [args2, cols, 'list-variants', no_imputation, recessive, dominant, error_on_freq_calc].join(' ')

    // speed up the calculation by only considering scoring-file variants for allele frequency calculation (--extract)
    if (scoremeta.n_scores.toInteger() == 1)
        """
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --seed 31 \
            --extract $scorefile \
            $load_afreq \
            $args \
            --score $scorefile $args2 \
            $input ${geno.baseName} \
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (scoremeta.n_scores.toInteger() > 1)
        """
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --seed 31 \
            --extract $scorefile \
            $load_afreq \
            $args \
            --score $scorefile $args2 \
            --score-col-nums 3-$maxcol \
            $input ${geno.baseName} \
            --out ${meta.id}_${meta.chrom}_${scoremeta.effect_type}_${scoremeta.n}

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
}
