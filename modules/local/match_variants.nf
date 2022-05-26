//
// At this stage, target genomic data might have come from:
//     - files pre-split by chromosome for larger datasets (e.g. UKBB) OR
//     - a single bfile set or VCF file for smaller datasets
//
// Splitting is only a performance benefit for big chungus datasets. Otherwise a
// lot of time is wasted provisioning containers and copying files etc.
//
// match_variants.py uses variant information that's been automatically combined
// (the sed / awk statement at the beginning). This is needed to properly match
// scorefiles, which aren't split, with target genomic data, which may be split.
//
// match_variants.py needs to know if the matched scoring files should be split.
// If an unsplit file is applied to split data, warnings happen.
//
// The second process input, chrom, is a list of chromosomes extracted from the meta map (the first input).
// Extracting the chrom data was needed for groupTuple() to succeed. When target
// genomic data are checked and staged, chromosome data are loaded from the
// samplesheet. If chromosomes are not specified, then chrom will be false.
// If chrom is not false, then split is true and match_variants.py is called with
// the --split option.
process MATCH_VARIANTS {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "conda-forge::pandas=1.1.5 sqlite" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:1.1.5' :
        'quay.io/biocontainers/pandas:1.1.5' }"

    input:
    tuple val(meta), val(chrom), path('??.pvar'), path(scorefile)

    output:
    tuple val(scoremeta), path("*.scorefile"), emit: scorefile
    path "report.csv"                   , emit: log
    path "versions.yml"                 , emit: versions

    script:
    def args = task.ext.args ?: ''
    def split = !chrom.contains(false)
    scoremeta = [:]
    scoremeta.id = "$meta.id"

    if (split)
        """
        sed -i '/##/d' *.pvar # delete annoying plink comment lines before combining
        awk 'FNR == 1 && NR != 1 { next } { print }' *.pvar > combined.txt

        match_variants.py \
            $args \
            --scorefile $scorefile \
            --target combined.txt \
            --split

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
            sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
        END_VERSIONS
        """
    else
        """
        sed -i '/##/d' *.pvar # delete annoying plink comment lines before combining
        awk 'FNR == 1 && NR != 1 { next } { print }' *.pvar > combined.txt

        match_variants.py \
            $args \
            --scorefile $scorefile \
            --target combined.txt

        cat <<-END_VERSIONS > versions.yml
        ${task.process.tokenize(':').last()}:
            python: \$(echo \$(python -V 2>&1) | cut -f 2 -d ' ')
            sqlite: \$(echo \$(sqlite3 -version 2>&1) | cut -f 1 -d ' ')
        END_VERSIONS
        """
}
