//
// Do a PCA on reference data and project target genomes into the PCA space
//

include { EXTRACT_DATABASE } from '../../../modules/local/ancestry/extract_database'
include { INTERSECT_VARIANTS } from '../../../modules/local/ancestry/intersect_variants'
include { FILTER_VARIANTS } from '../../../modules/local/ancestry/filter_variants'
include { PLINK2_MAKEBED } from '../../../modules/local/ancestry/plink2_makebed'
include { PLINK2_PCA } from '../../../modules/local/ancestry/plink2_pca'
include { RELABEL_IDS } from '../../../modules/local/ancestry/relabel_ids'
include { PLINK2_PROJECT } from '../../../modules/local/ancestry/plink2_project'

workflow ANCESTRY_OADP {
    take:
    geno
    pheno
    variants
    vmiss
    reference
    target_build

    main:
    ch_versions = Channel.empty()

    // sort order is _very important_
    // input order to modules must always be: geno, pheno, variants, e.g.:
    // .pgen, .psam, .pvar.zst in plink2
    // .bed, .fam, .bim.zst in plink1
    // it's assumed variants are zstd compressed at the start of the workflow
    geno.concat(pheno, variants)
        .groupTuple(size: 3, sort: { it.toString().split("\\.")[-1] } )
        .set { ch_genomes }

    //
    // STEP 0: extract the reference data once (don't do it inside separate processes)
    //

    EXTRACT_DATABASE( reference )

    EXTRACT_DATABASE.out.grch38
        .concat(EXTRACT_DATABASE.out.grch37)
        .filter { it.first().build == target_build }
        .set { ch_db }

    ch_versions = ch_versions.mix(EXTRACT_DATABASE.out.versions)

    //
    // STEP 1: get overlapping variants across reference and target ------------
    //

    Utils.submapCombine(ch_genomes.join(vmiss),
                        ch_db,
                        keys=['build'])
        .map { Utils.filterMapListByKey(it, key='id') } // (keep map at list head)
        .dump(tag: 'intersect_input')
        .set{ ch_ref_combined }

    INTERSECT_VARIANTS ( ch_ref_combined )
    ch_versions = ch_versions.mix(INTERSECT_VARIANTS.out.versions.first())

    //
    // STEP 2: filter variants in reference and target datasets ----------------
    //
    EXTRACT_DATABASE.out.grch37_king
        .concat(EXTRACT_DATABASE.out.grch38_king)
        .set { ch_king }

    // TODO: this is hardcoded and prevents custom reference support
    Channel.of(
         [['build': 'GRCh37'], file("$projectDir/assets/ancestry/high-LD-regions-hg19-GRCh37.txt", checkIfExists: true)],
         [['build': 'GRCh38'], file("$projectDir/assets/ancestry/high-LD-regions-hg38-GRCh38.txt", checkIfExists: true)]
    )
        .join(ch_king)
        .set{ ch_king_and_ld }

    // groupTuple always needs a size, so outputs can be streamed to the next process when they're ready
    // however, n_chrom may be different depending on sampleset
    // so construct a special groupKey to handle the case of multiple samplesets
    INTERSECT_VARIANTS.out.intersection
        .map { tuple(groupKey(it.first().subMap('id', 'build'), it.first().n_chrom),
                     it.last()) }
        .groupTuple() // groupKey has an implicit size
        .set { ch_intersected }

    // 1) combine ch_intersected with ch_db by build key
    //    (there may be multiple ch_intersected if multiple samplesets are in the run)
    // 2) combine 1) with ch_king_and_ld by build key
    // 3) filter extra hash maps from ch_db and ch_king_and_ld
    // 4) convert long flat list of match reports into a nested list in the resulting
    //     ch_filter_input channel
    Utils.submapCombine(
        Utils.submapCombine(
            ch_intersected,
            ch_db,
            ['build']),
        ch_king_and_ld,
        ['build'])
        .map { Utils.filterMapListByKey(it, 'id') }
        .map { Utils.listifyMatchReports(it) }
        .set { ch_filter_input }

    FILTER_VARIANTS ( ch_filter_input )

    FILTER_VARIANTS.out.ref
        .join(FILTER_VARIANTS.out.prune_in)
        .set { ch_pca_input }


    emit:
    intersection = INTERSECT_VARIANTS.out.intersection
    projections = Channel.empty() // PLINK2_PROJECT.out.projections
    ref_geno = Channel.empty() // ch_ref_branched.geno
    ref_pheno = Channel.empty() // ch_ref_branched.pheno
    ref_var = Channel.empty() // ch_ref_branched.var
    versions = ch_versions

}

def projection_error(int n) {
    // basic check to see if projection succeeded.
    // reference = 1, target = at least 1 (1 + 1 = 2)
    if (n < 2) {
        log.error "ERROR: Incomplete projections calculated!"
        System.exit(1)
    }
}
