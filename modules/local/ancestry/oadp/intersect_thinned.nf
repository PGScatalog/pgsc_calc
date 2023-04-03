//
// Variants matched from target to reference need to be intersected with
// thinned variants too
//

process INTERSECT_THINNED {
    scratch true
    // labels are defined in conf/modules.config
    label 'process_high_memory'
    label 'process_long'
    label 'plink2' // controls conda, docker, + singularity options

    tag "$meta.id"
    storeDir "$workDir/thinned_intersection/${params.target_build}/${meta.id}"

    conda (params.enable_conda ? "${task.ext.conda}" : null)

    container "${ workflow.containerEngine == 'singularity' &&
        !task.ext.singularity_pull_docker_container ?
        "${task.ext.singularity}${task.ext.singularity_version}" :
        "${task.ext.docker}${task.ext.docker_version}" }"

    input:
    tuple val(meta), path(matched), path(pruned), val(geno_meta), path(genomes)

    output:
    tuple val(meta), path("*_thinned.txt.gz"), emit: match_thinned
    tuple val(geno_meta), path("*.pgen"), emit: geno
    tuple val(geno_meta), path("*.pvar.gz"), emit: variants
    tuple val(geno_meta), path("*.psam"), emit: pheno
    path "versions.yml"           , emit: versions

    script:
    def args = task.ext.args ?: ''
    def mem_mb = task.memory.toMega() // plink is greedy

    // input options
    def input = (geno_meta.is_pfile) ? '--pfile' : '--bfile'

    """
    # 1) intersect thinned variants --------------------------------------------

    # can't do gunzip -c | head -n 1 -> returns exit code 141, breaks pipefail
    # https://stackoverflow.com/a/19120674
    # so awk prints the header from the first match file (FNR != NR && i == 0)
    awk 'BEGIN { i=0 } \
        NR!=FNR && FNR == 1 && i==0 { print; i++ } \
        NR==FNR { F1[\$0]; next } \
        \$2 in F1 { print }' \
        <(gunzip -c $pruned) \
        <(gunzip -c $matched) > ${meta.id}_ALL_matched_thinned.txt

    cut -f 7 -d ' ' ${meta.id}_ALL_matched_thinned.txt > ${meta.id}_shared.txt

    # 2) extract ld thinned variants and combine data if split -----------------
    # don't compress these files, because of pyplink reading limitations
    # in downstream fraposa process
    # (it's OK because the thinned files are quite small)

    echo $genomes | tr -s ' ' '\n' | cut -f 1 -d '.' | uniq > ids.txt

    # one file -> assume combined chrom data
    if [ \$(wc -l < ids.txt) -eq 1 ]
    then
        cp ids.txt autosomes.txt
    else
        # no sex chromosomes in reference data, so drop them from the ids list
        grep -E '.*_[0-9]+' ids.txt > autosomes.txt
    fi

    mkdir -p extracted
    while read f; do
        plink2 --threads $task.cpus \
            --memory $mem_mb \
            --seed 31 \
            $input \$f vzs \
            --extract ${meta.id}_shared.txt \
            --make-pgen \
            --sort-vars \
            --out extracted/\${f}_extracted
    done < autosomes.txt

    # one file -> assume combined chrom data
    if [ \$(wc -l < ids.txt) -eq 1 ]
    then
        mv extracted/*.p* .
    else
        plink2 --threads $task.cpus \
            --memory $mem_mb \
            --seed 31 \
            --pmerge-list <(sed "s/\$/_extracted/g" autosomes.txt) pfile \
            --pmerge-list-dir extracted \
            --delete-pmerge-result \
            --make-pgen \
            --sort-vars \
            --out ${meta.build}_${meta.id}_ALL_extracted
    fi

    # 3) clean up and compress -------------------------------------------------
    rm -r extracted autosomes.txt ids.txt
    gzip *.txt *.pvar

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
