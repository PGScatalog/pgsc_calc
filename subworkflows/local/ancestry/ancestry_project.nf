//
// Do a PCA on reference data and project target genomes into the PCA space
//

include { EXTRACT_DATABASE } from '../../../modules/local/ancestry/extract_database'
include { INTERSECT_VARIANTS } from '../../../modules/local/ancestry/intersect_variants'
include { FILTER_VARIANTS } from '../../../modules/local/ancestry/filter_variants'
include { PLINK2_MAKEBED as PLINK2_MAKEBED_TARGET; PLINK2_MAKEBED as PLINK2_MAKEBED_REF } from '../../../modules/local/ancestry/oadp/plink2_makebed'
include { INTERSECT_THINNED } from '../../../modules/local/ancestry/oadp/intersect_thinned'
include { RELABEL_IDS } from '../../../modules/local/ancestry/relabel_ids'
include { PLINK2_ORIENT } from '../../../modules/local/ancestry/oadp/plink2_orient'
include { FRAPOSA_PCA } from '../../../modules/local/ancestry/oadp/fraposa_pca'
include { FRAPOSA_PROJECT } from '../../../modules/local/ancestry/oadp/fraposa_project'

workflow ANCESTRY_PROJECT {
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

    // prepare reference data channels for emit to scoring subworkflow
    ch_db.map {
        meta = it.first().clone()
        meta.is_pfile = true
        meta.id = 'reference'
        meta.chrom = 'ALL'
        return tuple(meta, it.tail())
    }
        .transpose()
        .branch {
            geno: it.last().getExtension() == 'pgen'
            pheno: it.last().getExtension() == 'psam'
            var: it.last().getExtension() == 'zst'
        }
        .set{ ch_ref_branched }

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

    // filtering isn't strictly necessary:
    // one channel will be empty, EXTRACT_DATABASE only extracts the input build
    // but it's worth keeping just in case anything untoward happens
    EXTRACT_DATABASE.out.grch37_king
        .concat(EXTRACT_DATABASE.out.grch38_king)
        .filter { it.first().build == params.target_build }
        .set { ch_king }

    // TODO: this is hardcoded and prevents custom reference support
    Channel.of(
        [['build': 'GRCh37'], file(params.ld_grch37, checkIfExists: true)],
        [['build': 'GRCh38'], file(params.ld_grch38, checkIfExists: true)]
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
        .map { m = it.first().plus([:])
              return [m, it.tail()]
        }
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
    ch_versions = ch_versions.mix(FILTER_VARIANTS.out.versions)
    // -------------------------------------------------------------------------
    // ref -> thinned bfile for fraposa
    //
    FILTER_VARIANTS.out.ref
        .join( FILTER_VARIANTS.out.prune_in, by: 0 )
        .map {
            m = it.first().clone()
            m.id = 'reference'
            m.chrom = 'ALL'
            m.is_pfile = true
            return tuple(m, it.tail()).flatten()
        }
        .set { ch_makebed_ref }

    PLINK2_MAKEBED_REF ( ch_makebed_ref )

    ch_versions = ch_versions.mix(PLINK2_MAKEBED_REF.out.versions)
    // -------------------------------------------------------------------------
    // targets -> intersect with thinned reference variants
    // combine split targets into one file
    // relabel
    // then convert to bim

    Utils.submapCombine(
        ch_intersected,
        FILTER_VARIANTS.out.prune_in,
        ['build']
    )
        .map { Utils.filterMapListByKey(it, 'id') }
        .map { Utils.listifyMatchReports(it) }
        .map { [ it.first().subMap('build', 'id'), it] }
        .set { ch_intersect_thin_input }

    ch_genomes.map { [groupKey(it.first().subMap('build', 'id', 'is_pfile', 'is_bfile'), it.first().n_chrom), it] }
        .groupTuple()
        .map { m = it.first().plus([:])
              return [m, it.tail()]
        }
        .map{ Utils.filterMapListByKey(it.flatten(), 'chrom', drop=true) }
        .map{ [ it.first().subMap('build', 'id'), it.head(), it.tail() ] }
        .set{ ch_combined_genomes }

    ch_intersect_thin_input.join(ch_combined_genomes, by: 0)
        .map { it.tail().first() + it.tail().tail() }
        // [meta, [matches], pruned, geno_meta, [gigantic list of pfiles]]
        .set { ch_intersect_thinned_input }

    // extract & merge split targets
    INTERSECT_THINNED ( ch_intersect_thinned_input )
    // TODO: why are versions bork?
    // ch_versions = ch_versions.mix(INTERSECT_THINNED.out.versions)

    Utils.submapCombine(
        INTERSECT_THINNED.out.match_thinned,
        INTERSECT_THINNED.out.variants,
        ['build', 'id']
    )
        .map{ Utils.filterMapListByKey(it, 'is_pfile', drop=true) }
        .set { ch_thinned_target }

    RELABEL_IDS( ch_thinned_target )
    ch_versions = ch_versions.mix(RELABEL_IDS.out.versions)

    RELABEL_IDS.out.relabelled
        .map { [it.first(), it.last().findAll { it.getName().contains("_ALL_") }].flatten() }
        .set { ch_target_relabelled }

    target_extract = Channel.of(file('NO_FILE')) // optional input for PLINK2_MAKEBED
    Utils.submapCombine(
        INTERSECT_THINNED.out.geno.join(INTERSECT_THINNED.out.pheno, by: 0),
        ch_target_relabelled,
        ['build', 'id']
    )
        .map { Utils.filterMapListByKey(it, 'target_format', drop=true) }
        .combine(target_extract)
        .set { ch_target_makebed_input }

    PLINK2_MAKEBED_TARGET ( ch_target_makebed_input )

    // make sure allele order matches across ref / target ----------------------
    // (because plink1 format is very annoying about this sort of thing)

    PLINK2_MAKEBED_TARGET.out.geno
        .concat(PLINK2_MAKEBED_TARGET.out.pheno, PLINK2_MAKEBED_TARGET.out.variants)
        .groupTuple(size: 3)
        .combine(PLINK2_MAKEBED_REF.out.variants)
        .map{ Utils.filterMapListByKey(it, 'chrom', drop=true).flatten() }
        .set { ch_orient_input }

    PLINK2_ORIENT( ch_orient_input )

    // fraposa -----------------------------------------------------------------

    PLINK2_MAKEBED_REF.out.geno
        .concat(PLINK2_MAKEBED_REF.out.pheno, PLINK2_MAKEBED_REF.out.variants)
        .groupTuple(size: 3)
        .set { ch_fraposa_ref }

    PLINK2_MAKEBED_TARGET.out.splits
        .transpose()
        .set { ch_split_targets }

    PLINK2_ORIENT.out.geno
        .concat(PLINK2_ORIENT.out.pheno, PLINK2_ORIENT.out.variants)
        .groupTuple(size: 3)
        .combine(ch_split_targets, by: 0)
        .set { ch_fraposa_target }

    // do PCA on reference genomes...
    FRAPOSA_PCA( ch_fraposa_ref.map { it.flatten() } )

    // TODO: update samplesheet, reference is a reserved sampleset name
    // ... and project split target genomes

    ch_fraposa_ref
        .combine( ch_fraposa_target )
        .flatten()
        .filter{ !(it instanceof LinkedHashMap) || it.id == 'reference' }
        .buffer(size: 8)
        .combine(FRAPOSA_PCA.out.pca.map{ [it] })
        .set { ch_fraposa_input }

    // project targets into reference PCA space
    FRAPOSA_PROJECT( ch_fraposa_input )

    // group together ancestry projections for each sampleset
    // different samplesets will have different ancestry projections after intersection
    FRAPOSA_PROJECT.out.pca
        .groupTuple() // todo: set size
        .set { ch_projections }

    emit:
    intersection = INTERSECT_VARIANTS.out.intersection
    projections = ch_projections
    ref_geno = ch_ref_branched.geno
    ref_pheno = ch_ref_branched.pheno
    ref_var = ch_ref_branched.var
    relatedness = ch_king
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
