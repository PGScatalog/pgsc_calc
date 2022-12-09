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

    """
    plink2 --zst-decompress $pvar \
        | grep -vE "^#" \
        | awk '{if(\$4 \$5 == "AT" || \$4 \$5 == "TA" || \$4 \$5 == "CG" || \$4 \$5 == "GC") print \$3}' \
        > 1000G_StrandAmb.txt

    plink2 --pfile ${pgen.simpleName} vzs \
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
        --out ${pgen.simpleName}_${meta.build}_qc
    """
}
