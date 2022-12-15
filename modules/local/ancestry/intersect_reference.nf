process INTERSECT_REFERENCE {
    tag "$meta.id chromosome $meta.chrom"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::plink2==2.00a3.3" : null)
    def dockerimg = "${ params.platform == 'amd64' ?
        'quay.io/biocontainers/plink2:2.00a3.3--hb2a7ceb_0' :
        'dockerhub.ebi.ac.uk/gdp-public/pgsc_calc/plink2:arm64-2.00a3.3' }"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a3.3--hb2a7ceb_0' :
        dockerimg }"

    input:
    tuple val(meta), path(geno), path(pheno), path(variants), path(ld),
        path(ref_geno), path(ref_pheno), path(ref_variants)

    output:
    tuple val(build), path("*.prune.in.gz"), emit: ref_intersect
    path "versions.yml", emit: versions

    script:
    def mem_mb = task.memory.toMega() // plink is greedy
    build = meta.subMap('build')

    // bfile and pfile needs distinct processes here, because:
    //     - bim and pvar IDs are stored in different column idxs
    //     - --make-just-pvar / --make-just-bim must be different
    if (meta.is_pfile)
        """
        # 1. exclude variants with high-missingness in the target dataset
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --pfile vzs ${geno.simpleName} \
            --geno 0.5 \
            --make-just-pvar zs \
            --out low_missingness

        # 2. find intersection of variant ids
        plink2 --zst-decompress low_missingness.pvar.zst | \
            grep -vE "^#" | \
            cut -f 3 | \
            sort -u  |
            gzip > target_vid.txt.gz

        plink2 --zst-decompress $ref_variants | \
            grep -vE "^#" | \
            cut -f 3 | \
            sort -u | \
            comm -12 <(zcat target_vid.txt.gz) - | \
            gzip > shared_vid.txt.gz

        # 3. extract shared variants and ld thin
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --pfile vzs ${ref_geno.simpleName} \
            --extract shared_vid.txt.gz \
            --indep-pairwise 1000 50 0.05 \
            --exclude range $ld \
            --out ${geno.simpleName}_thinned

        # 4. gzip prune outputs
        gzip *.prune*

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else if (meta.is_bfile)
        """
        # 1. exclude variants with high-missingness in the target dataset
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --bfile vzs ${geno.simpleName} \
            --geno 0.5 \
            --make-just-bim zs \
            --out low_missingness

        # 2. find intersection of variant ids
        plink2 --zst-decompress low_missingness.bim.zst | \
            grep -vE "^#" | \
            cut -f 2 | \
            sort -u | \
            gzip > target_vid.txt.gz

        plink2 --zst-decompress $ref_variants | \
            grep -vE "^#" | \
            cut -f 3 | \
            sort -u | \
            comm -12 <(zcat target_vid.txt.gz) - | \
            gzip > shared_vid.txt.gz

        # 3. extract shared variants and ld thin
        plink2 \
            --threads $task.cpus \
            --memory $mem_mb \
            --bfile vzs ${ref_geno.simpleName} \
            --extract shared_vid.txt.gz \
            --indep-pairwise 1000 50 0.05 \
            --exclude range $ld \
            --out ${geno.simpleName}_thinned

        # 4. gzip prune outputs
        gzip *.prune*

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
        END_VERSIONS
        """
    else
        """
        echo 'STRANGE ERROR: meta.is_bfile and meta.is_pfile both false'
        exit 1
        """
}
