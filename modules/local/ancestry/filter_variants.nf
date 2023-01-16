process FILTER_VARIANTS {
    tag "$meta.id $meta.build"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(ref_geno), path(ref_pheno), path(ref_var),
        val(matchmeta), path(shared), path(ld), path(king)

    output:
    tuple val(meta), path("*_reference.pgen"), path("*_reference.psam"), path("*_reference.pvar.zst"), emit: ref
    tuple val(meta), path("*thinned.prune.in.gz"), emit: prune_in
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy

    // dynamic input option
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'
    """
    # 1. Get QC'd variant set & unrelated samples from REFERENCE data for PCA --

    # (STRANDAMB == TRUE)
    awk '\$5 == 1 { print \$2 }' <(zcat $shared) | gzip -c > 1000G_StrandAmb.txt.gz

    # ((IS_INDEL == FALSE) && (STRANDAMB == FALSE) || ((IS_INDEL == TRUE)) && (SAME_REF == TRUE))
    awk '((\$4 == 0) && (\$5 == 0)) || ((\$4 == 0) && (\$8 == 1)) {print \$2}' <(zcat $shared) | gzip -c > shared.txt.gz

    plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --pfile ${ref_geno.simpleName} vzs \
            --remove $king \
            --extract shared.txt.gz \
            --exclude 1000G_StrandAmb.txt.gz \
            --max-alleles 2 \
            --snps-only just-acgt \
            --rm-dup exclude-all \
            --geno 0.1 \
            --mind 0.1 \
            --maf 0.01 \
            --hwe 0.000001 \
            --make-pgen vzs \
            --allow-extra-chr --autosome \
            --out ${meta.build}_reference

    # 3. LD-thin variants in REFERENCE (filtered variants & samples) for input
    # into PCA -----------------------------------------------------------------
    plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --pfile vzs ${meta.build}_reference \
            --indep-pairwise 1000 50 0.05 \
            --exclude range $ld \
            --out ${ref_geno.simpleName}_thinned

    gzip *.prune.in *.prune.out

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
