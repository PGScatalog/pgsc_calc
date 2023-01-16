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
    tuple val(meta), path(geno), path(pheno), path(var), path(shared),
        path(ref_geno), path(ref_pheno), path(ref_var),
        path(ld), path(king)

    output:
    tuple val(meta), path("*_reference.pgen"), path("*_reference.psam"), path("*_reference.pvar.zst"), path("*thinned.prune.in.gz"), emit: ref
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy

    // dynamic input option
    def input = (meta.is_pfile) ? '--pfile vzs' : '--bfile vzs'
    """
    # 1. identify variants with high-missingness in the TARGET dataset ---------
    plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            $input ${geno.simpleName} \
            --geno 0.5 \
            --make-just-pvar zs \
            --out low_missingness

    # 2. Get QC'd variant set & unrelated samples from REFERENCE data for PCA --

    # --zst-decompress can't be used with mem / threads flags
    plink2 \
            --zst-decompress $ref_var \
            | grep -vE "^#" \
            | awk '{if(\$4 \$5 == "AT" || \$4 \$5 == "TA" || \$4 \$5 == "CG" || \$4 \$5 == "GC") print \$3}' \
        > 1000G_StrandAmb.txt

    plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --pfile ${ref_geno.simpleName} vzs \
            --remove $king \
            --extract $shared \
            --exclude 1000G_StrandAmb.txt \
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
