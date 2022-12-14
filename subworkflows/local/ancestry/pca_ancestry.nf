//
//
//

include { EXTRACT_DATABASE } from '../../../modules/local/ancestry/extract_database'
include { INTERSECT_REFERENCE } from '../../../modules/local/ancestry/intersect_reference'
include { PLINK2_PCA } from '../../../modules/local/ancestry/plink2_pca'

workflow PCA_ANCESTRY {
    take:
    geno
    pheno
    variants
    reference

    main:
    // extract the reference data once, don't do it inside a process
    EXTRACT_DATABASE( reference )

    EXTRACT_DATABASE.out.grch38
        .concat(EXTRACT_DATABASE.out.grch37)
        .set { ch_db }

    Channel.of(
        [['build': 'GRCh37'], file("$projectDir/assets/ancestry/high-LD-regions-hg19-GRCh37.txt", checkIfExists: true)],
        [['build': 'GRCh38'], file("$projectDir/assets/ancestry/high-LD-regions-hg38-GRCh38.txt", checkIfExists: true)]
    )
        .join(ch_db)
        .set{ ch_ref }

    // sort order is _very important_
    // input order to modules must always be: geno, pheno, variants, e.g.:
    // .pgen, .psam, .pvar.zst in plink2
    // .bed, .fam, .bim.zst in plink1
    // it's assumed variants are zstd compressed at the start of the workflow
    geno.concat(pheno, variants)
        .groupTuple(size: 3, sort: { it.toString().split("\\.")[-1] } )
        .set { ch_genomes }

    ch_genomes
        // copy build to first element, use as a key, and drop it
        .map { it -> [it.first().subMap(['build']), it] }
        .combine ( ch_ref, by: 0 )
        .map { it.tail() }
        .map { it.flatten() }
        .dump(tag: 'intersect_input')
        .set{ ch_ref_combined }

    INTERSECT_REFERENCE ( ch_ref_combined )

    ch_db
        .join( INTERSECT_REFERENCE.out.ref_intersect )
        .map { it.flatten() }
        .dump(tag: 'pca_input')
        .set { ch_pca_input }

    PLINK2_PCA ( ch_pca_input )

    // TODO: project reference and input genomes
    // PLINK2_PROJECT?

    // output: projections?
}
