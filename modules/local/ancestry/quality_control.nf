process QUALITY_CONTROL {
    tag "$meta.build $meta.id chromosome $meta.chrom"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(king), path(pgen), path(psam), path(pvar)

    output:
    tuple val(meta), path("*.pgen"), path("*.psam"), path("*.pvar.zst"), emit: plink
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    """
    # --zst-decompress can't be used with mem / threads flags
    plink2 \
        --zst-decompress $pvar \
        | grep -vE "^#" \
        | awk '{if(\$4 \$5 == "AT" || \$4 \$5 == "TA" || \$4 \$5 == "CG" || \$4 \$5 == "GC") print \$3}' \
        > 1000G_StrandAmb.txt

    plink2 \
        --threads $task.cpus \
        --memory $mem_mb \
        --pfile ${pgen.simpleName} vzs \
        --remove $king \
        --exclude 1000G_StrandAmb.txt \
        --max-alleles 2 \
        --snps-only just-acgt \
        --rm-dup exclude-all \
        --geno 0.1 \
        --mind 0.1 \
        --maf 0.01 \
        --hwe 0.000001 \
        --autosome \
        --make-pgen vzs \
        --allow-extra-chr \
        --chr 1-22 \
        --out ${meta.build}_reference

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
