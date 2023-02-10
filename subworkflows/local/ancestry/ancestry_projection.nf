//
//
//

include { EXTRACT_DATABASE } from '../../../modules/local/ancestry/extract_database'
include { INTERSECT_VARIANTS } from '../../../modules/local/ancestry/intersect_variants'
include { FILTER_VARIANTS } from '../../../modules/local/ancestry/filter_variants'
include { PLINK2_PCA } from '../../../modules/local/ancestry/plink2_pca'
include { RELABEL_IDS } from '../../../modules/local/ancestry/relabel_ids'
include { PLINK2_PROJECT } from '../../../modules/local/ancestry/plink2_project'

workflow ANCESTRY_PROJECTION {
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

    ch_genomes
        .join(vmiss)
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
    // STEP 2: filter variants in reference and target datasets ----------------
    //
    EXTRACT_DATABASE.out.grch37_king
        .concat(EXTRACT_DATABASE.out.grch38_king)
        .set { ch_king }

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
        .groupTuple()
        // temporarily set build as key for joining with reference data
        .map { it -> tuple(it.first().subMap(['build']), it) }
        .set { ch_intersected }

    ch_intersected
        .combine(ch_db, by: 0 )
        .combine(ch_king_and_ld, by: 0 )
        // this seems like an unpleasant way to do things. how to flatten one level of a groovy list?
        // [meta.id, meta.build], list[intersected], ref_geno, ref_var, ref_pheno, ld, king
        .map { tuple(it[1][0], it[1][1], it[2], it[3], it[4], it[5], it[6]) }
        .set { ch_filter_input }

    FILTER_VARIANTS ( ch_filter_input )

    FILTER_VARIANTS.out.ref
        .join(FILTER_VARIANTS.out.prune_in)
        .set { ch_pca_input }

    //
    // STEP 2: Derive PCA on reference population ------------------------------
    //

    PLINK2_PCA ( ch_pca_input )
    ch_versions = ch_versions.mix(PLINK2_PCA.out.versions)

    //
    // STEP 3: Rekey PCA output for use on target datasets ---------------------
    //

    PLINK2_PCA.out.afreq
        .concat(PLINK2_PCA.out.eigenvec_var)
        .set { ch_pca_output }

    ch_intersected
        .map { tuple(it[1][0], it[1][1]) }
        .combine( ch_pca_output )
        .set { ch_relabel_input }

    RELABEL_IDS( ch_relabel_input )

    RELABEL_IDS.out.relabelled
        // extract key from meta map as first element
        .map { tuple(it.first().subMap('id', 'build'), it) }
        .branch {
            var: it.last().first().target_format == 'var'
            afreq: it.last().first().target_format == 'afreq'
        }
        .set { ch_relabel_output }

    //
    // STEP 4: Project reference and target samples into PCA space -------------
    //

    ch_genomes
        // extract key from meta map as first element for combining
        .map { it -> [it.first().subMap(['id', 'build']), it] }
        .combine ( ch_relabel_output.var, by: 0 )
        .combine ( ch_relabel_output.afreq, by: 0 )
        .map { it.tail().flatten() } // now drop the key
        // findAll() cleanly drops redundant hashmaps (keeps first one)
        // TODO: replace horrible list slicing with findAll()
        .map { it.findAll { !(it.getClass() == LinkedHashMap &&
                              it.containsKey('target_format')) } }
        .dump(tag: 'target_project_input')
        // [meta, geno, pheno, var, eigenvec, afreq]
        .set { ch_target_project_input }

    // associate the reference database with each unique sampleset
    // so it's possible to join the reference channel with the rekeyed data

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: think about this again
    //   - it's running the reference projection once per sampleset
    //   - afreq and vars are taken from the associated sampleset
    //   - should we project the reference data once and combine the results with
    //   each sampleset?
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    ch_genomes.map { it.first().id }.unique().set { ch_samplesets }

    ch_db
        .combine( ch_samplesets )
        .map {
            // cloning because don't want to modify meta object in place
            m = it.first().clone()
            m.id = it.last()
            it.removeLast()
            return tuple(m, it.tail()).flatten()
        }
        .combine ( ch_relabel_output.var, by: 0 )
        .combine ( ch_relabel_output.afreq, by: 0 )
        .map { m = it.first().clone()
              // add important information for PLINK2_PROJECT
              // must happen after .combine() matches by key
              m.chrom = 'ALL'
              m.is_pfile = true
              return tuple(m, it.tail()).flatten()
        }
        .map { it.findAll { !(it.getClass() == LinkedHashMap &&
                              it.containsKey('target_format')) } }
        .set { ch_ref_project_input }

    ch_target_project_input
        .concat ( ch_ref_project_input )
        .set { ch_project_input }

    PLINK2_PROJECT( ch_project_input )
    ch_versions = ch_versions.mix(PLINK2_PROJECT.out.versions.first())

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

    emit:
    intersection = INTERSECT_VARIANTS.out.intersection
    projections = PLINK2_PROJECT.out.projections
    ref_geno = ch_ref_branched.geno
    ref_pheno = ch_ref_branched.pheno
    ref_var = ch_ref_branched.var
    versions = ch_versions

}
