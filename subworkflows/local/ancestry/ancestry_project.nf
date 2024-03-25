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
    afreq
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

    ch_genomes
        .first()
        .map{ it.first().subMap('id') }
        .set { ch_sampleset }

    //
    // STEP 0: extract the reference data once (don't do it inside separate processes)
    //

    EXTRACT_DATABASE( reference )

    EXTRACT_DATABASE.out.grch38
        .concat(EXTRACT_DATABASE.out.grch37)
        .filter { it.first().build == target_build }
        .set { ch_db }

    ch_versions = ch_versions.mix(EXTRACT_DATABASE.out.versions.first())

    ch_db.map {
        def meta = [:].plus(it.first())
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
        .set{ ch_ref }

    //
    // STEP 1: get overlapping variants across reference and target ------------
    //

    ch_genomes
        .join(vmiss, failOnMismatch: true)
        .combine( ch_db.map{ it.tail() } ) // (drop hashmap)
        .flatten()
        .buffer(size: 8)
        .set { ch_ref_combined }

    INTERSECT_VARIANTS ( ch_ref_combined )
    ch_versions = ch_versions.mix(INTERSECT_VARIANTS.out.versions.first())

    //
    // STEP 2: filter variants in reference and target datasets ----------------
    //

    EXTRACT_DATABASE.out.grch37_king
        .concat(EXTRACT_DATABASE.out.grch38_king)
        .filter { it.first().build == params.target_build }
        .map { it.last() }
        .set { ch_king }

    Channel.of(
        [['build': 'GRCh37'], file(params.ld_grch37, checkIfExists: true)],
        [['build': 'GRCh38'], file(params.ld_grch38, checkIfExists: true)]
    )
        .filter{ it.first().build == params.target_build }
        .map{ it.last() }
        .set{ ch_ld }

    INTERSECT_VARIANTS.out.intersection
        .map{ it.last() }
        .collect()
        .set { ch_match_reports }

    ch_sampleset.concat( ch_match_reports )
        .concat( ch_db.map{ it.tail() }.flatten() )
        .concat( ch_ld )
        .concat( ch_king )
        .buffer(size: 7)
        .set{ ch_filter_input }

    FILTER_VARIANTS ( ch_filter_input )
    ch_versions = ch_versions.mix(FILTER_VARIANTS.out.versions.first())

    // -------------------------------------------------------------------------
    // ref -> thinned bfile for fraposa
    //

    FILTER_VARIANTS.out.ref
        .map {
            def m = [:].plus(it.first())
            m.id = 'reference'
            m.chrom = 'ALL'
            m.is_pfile = true
            return tuple(m, it.tail()).flatten()
        }
        .concat( FILTER_VARIANTS.out.prune_in)
        .flatten()
        .buffer(size: 5)
        .set { ch_makebed_ref }

    PLINK2_MAKEBED_REF ( ch_makebed_ref )
    ch_versions = ch_versions.mix(PLINK2_MAKEBED_REF.out.versions.first())

    // -------------------------------------------------------------------------
    // 0. targets -> intersect with thinned reference variants
    // 1. combine split targets into one file
    // 2. relabel
    // 3. then convert to bim

    ch_genomes
        .first()
        .map{ it.first() }
        .set { ch_geno_meta }

    ch_genomes
        .map { it.last() }
        .collect()
        .set { ch_genome_list }

    // [meta, [matches], pruned, geno_meta, [gigantic list of all pfiles]]
    ch_sampleset
        .map { it.plus(['build': params.target_build]) }
        .concat( ch_match_reports )
        .concat( FILTER_VARIANTS.out.prune_in )
        .concat( ch_geno_meta )
        .concat( ch_genome_list )
        .buffer( size: 5 )
        .set{ ch_intersect_thinned_input }

    INTERSECT_THINNED ( ch_intersect_thinned_input )
    //ch_versions = ch_versions.mix(INTERSECT_THINNED.out.versions)

    // [meta, variants, thinned]
    INTERSECT_THINNED.out.variants
        .concat(INTERSECT_THINNED.out.match_thinned)
        .flatten()
        .buffer(size: 3)
        .set { ch_thinned_target }

    RELABEL_IDS( ch_thinned_target )
    ch_versions = ch_versions.mix(RELABEL_IDS.out.versions.first())

    RELABEL_IDS.out.relabelled
        .flatten()
        .filter{ it instanceof Path && it.getName().contains('ALL') }
        .set { ch_ref_relabelled_variants }

    target_extract = Channel.of(file(projectDir / "assets" / "NO_FILE")) // optional input for PLINK2_MAKEBED

    // [meta, pgen, psam, relabelled pvar, optional_input]
    INTERSECT_THINNED.out.geno
        .join(INTERSECT_THINNED.out.pheno, by: 0)
        .concat( ch_ref_relabelled_variants )
        .concat(target_extract)
        .flatten()
        .buffer(size: 5)
        .set{ ch_target_makebed_input }

    PLINK2_MAKEBED_TARGET ( ch_target_makebed_input )
    ch_versions = ch_versions.mix(PLINK2_MAKEBED_TARGET.out.versions.first())

    // make sure allele order matches across ref / target ----------------------
    // (because plink1 format is very annoying about this sort of thing)

    // [meta, target_pgen, target_psam, target_pvar, ref_pvar]
    PLINK2_MAKEBED_TARGET.out.geno
        .concat(PLINK2_MAKEBED_TARGET.out.pheno, PLINK2_MAKEBED_TARGET.out.variants)
        .groupTuple(size: 3)
        .concat(PLINK2_MAKEBED_REF.out.variants.map { it.last() })
        .flatten()
        .buffer(size: 5)
        .set{ ch_orient_input }

    PLINK2_ORIENT( ch_orient_input )
    ch_versions = ch_versions.mix(PLINK2_ORIENT.out.versions.first())

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

    FRAPOSA_PCA( ch_fraposa_ref.map { it.flatten() }, geno )
    ch_versions = ch_versions.mix(FRAPOSA_PCA.out.versions.first())

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
    ch_versions = ch_versions.mix(FRAPOSA_PROJECT.out.versions.first())

    // group together ancestry projections for each sampleset
    // different samplesets will have different ancestry projections after intersection
    FRAPOSA_PCA.out.pca
        .flatten()
        .filter { it.getExtension() == 'pcs' }
        .map { [it] }
        .set { ch_ref_projections }

    FRAPOSA_PROJECT.out.pca
        .groupTuple()
        .set { ch_projections }

    // projections are a mandatory output of the subworkflow
    def project_fail = true
    FRAPOSA_PROJECT.out.pca.subscribe onNext: { project_fail = false },
        onComplete: { projection_error(project_fail) }

    emit:
    intersection = INTERSECT_VARIANTS.out.intersection
    intersect_count = INTERSECT_VARIANTS.out.intersect_count.collect()
    projections = ch_projections.combine(ch_ref_projections)
    ref_geno = ch_ref.geno
    ref_pheno = ch_ref.pheno
    ref_var = ch_ref.var
    relatedness = ch_king
    ref_afreq = FILTER_VARIANTS.out.afreq
    versions = ch_versions

}

def projection_error(boolean fail) {
    if (fail) {
        log.error "ERROR: Projection subworkflow failed"
        System.exit(1)
    }
}
