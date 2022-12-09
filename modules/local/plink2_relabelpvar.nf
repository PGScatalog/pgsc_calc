// TODO: add build to meta
process PLINK2_RELABELPVAR {
    tag "$meta.id chromosome $meta.chrom"
    storeDir ( params.genotypes_cache ? "$params.genotypes_cache/${meta.build}/${meta.id}/${meta.chrom}" :
              "$workDir/genomes/${meta.build}/${meta.id}/${meta.chrom}/")
    label 'process_low'
    label "${ params.copy_genomes ? 'copy_genomes' : '' }"

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    // input is sorted alphabetically -> bed, bim, fam or pgen, psam, pvar
    tuple val(meta), path(geno), path(pheno), path(variants)

    output:
    tuple val(meta), path("*.pgen"), emit: geno
    tuple val(meta), path("*.zst") , emit: variants
    tuple val(meta), path("*.psam"), emit: pheno
    path "versions.yml"            , emit: versions

    when:
    // only execute when pfile because output format is different (bim vs pvar)
    meta.is_pfile

    script:
    def args = task.ext.args ?: ''
    def compressed = variants.getName().endsWith("zst") ? 'vzs' : ''
    def prefix = task.ext.suffix ? "${meta.id}${task.ext.suffix}" : "${meta.id}"
    def mem_mb = task.memory.toMega() // plink is greedy
    // if dropping multiallelic variants, set a generic ID that won't match
    def set_ma_missing = params.keep_multiallelic ? '' : '--var-id-multi @:#'


    """
    plink2 \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        $args \\
        --set-all-var-ids '@:#:\$r:\$a' \\
        $set_ma_missing \\
        --pfile ${geno.baseName} $compressed \\
        --make-just-pvar zs \\
        --out ${prefix}_${meta.chrom}

    cp -RP $geno ${prefix}_${meta.chrom}.pgen
    cp -RP $pheno ${prefix}_${meta.chrom}.psam

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}
