//
//
//

include { EXTRACT_DATABASE } from '../../../modules/local/ancestry/extract_database'
include { INTERSECT_VARIANTS } from '../../../modules/local/ancestry/intersect_variants'
include { FILTER_VARIANTS } from '../../../modules/local/ancestry/filter_variants'
include { PLINK2_PCA } from '../../../modules/local/ancestry/plink2_pca'
include { PLINK2_PROJECT } from '../../../modules/local/ancestry/plink2_project'

workflow ANCESTRY_PROJECTION {
    take:
    geno
    pheno
    variants
    reference
    target_build

    main:
    ch_versions = Channel.empty()

    //
    // STEP 0: extract the reference data once (don't do it inside separate processes)
    //
    EXTRACT_DATABASE( reference )

    EXTRACT_DATABASE.out.grch38
        .concat(EXTRACT_DATABASE.out.grch37)
        .set { ch_db }

    ch_versions = ch_versions.mix(EXTRACT_DATABASE.out.versions)

    //
    // STEP 1: get overlapping variants across reference and target ------------
    //

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
        .combine ( ch_db, by: 0 )
        .map { it.tail() }
        .map { it.flatten() }
        .dump(tag: 'intersect_input')
        .set{ ch_ref_combined }

    INTERSECT_VARIANTS ( ch_ref_combined )
    ch_versions = ch_versions.mix(INTERSECT_VARIANTS.out.versions)

    //
    // STEP 2: filter variants in reference and target datasets
    //
    EXTRACT_DATABASE.out.grch37_king
        .concat(EXTRACT_DATABASE.out.grch38_king)
        .set { ch_king }

    Channel.of(
         [['build': 'GRCh37'], file("$projectDir/assets/ancestry/high-LD-regions-hg19-GRCh37.txt", checkIfExists: true)],
         [['build': 'GRCh38'], file("$projectDir/assets/ancestry/high-LD-regions-hg38-GRCh38.txt", checkIfExists: true)]
    )
        .join(ch_king)
        .set{ ch_ref_data }

    ch_db
        .map { it -> [it.first().subMap(['build']), it] }
        .combine ( ch_ref_data, by: 0 )
        .map { it.tail() }
        .map { it.flatten() }
        .dump(tag: 'intersect_input')
        .filter { it.first().build == target_build }
        .set{ ch_ref_raw }

    ch_genomes.join(INTERSECT_VARIANTS.out.intersection, by: 0)
        .map { it -> [it.first().subMap(['build']), it] }
        .combine ( ch_ref_raw, by: 0 )
        .map { it.tail() }
        .map { it.flatten() }
        .set { ch_filter_input }

    FILTER_VARIANTS ( ch_filter_input )

    //
    // STEP 2: Derive PCA on reference population
    //

    // ch_db
    //     .join( INTERSECT_REFERENCE.out.ref_intersect )
    //     .map { it.flatten() }
    //     .dump(tag: 'pca_input')
    //     .set { ch_pca_input }


    // PLINK2_PCA ( ch_pca_input )
    // ch_versions = ch_versions.mix(PLINK2_PCA.out.versions)

    //
    // STEP 3: Project reference and target samples into PCA space
    //
    // PLINK2_PCA.out.afreq
    //     .concat(PLINK2_PCA.out.eigenvec_var)
    //     .groupTuple()
    //     .set{ ch_pca_output }

    // ch_genomes
    // // copy build to first element, use as a key, and drop it
    //     .map { it -> [it.first().subMap(['build']), it] }
    //     .combine ( ch_pca_output, by: 0 )
    //     .map { it.tail() }
    //     .map { it.flatten() }
    //     .dump(tag: 'target_project_input')
    //     .set { ch_target_project_input }

    // ch_db
    //     .filter { it.first().get('build') == params.target_build }
    //     .combine ( ch_pca_output, by: 0 )
    // // add is_pfile to meta map, because PLINK2_PROJECT must handle bfile or pfile
    //     .map { it -> [['build': params.target_build, 'chrom': 'ALL',
    //                    'id': 'reference', 'is_pfile': true], it.tail()] }
    //     .map { it.flatten() }
    //     .concat ( ch_target_project_input )
    //     .dump(tag: 'all_project_input')
    //     .set { ch_all_project_input }


    // PLINK2_PROJECT( ch_all_project_input )
    // ch_versions = ch_versions.mix(PLINK2_PROJECT.out.versions.first())

    emit:
    intersection = INTERSECT_VARIANTS.out.intersection
    projections = Channel.empty() // PLINK2_PROJECT.out.projections
    versions = Channel.empty() // ch_versions

}
