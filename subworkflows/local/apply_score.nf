//
// Apply a validated scoring file to the QC'd target genomic data
//
import java.util.zip.GZIPInputStream

include { RELABEL_SCOREFILES } from '../../modules/local/ancestry/relabel_scorefiles'
include { RELABEL_AFREQ } from '../../modules/local/ancestry/relabel_afreq'
include { PLINK2_SCORE }    from '../../modules/local/plink2_score'
include { SCORE_AGGREGATE } from '../../modules/local/score_aggregate'
include { SCORE_REPORT    } from '../../modules/local/score_report'

workflow APPLY_SCORE {
    take:
    geno
    pheno
    variants
    intersection
    scorefiles
    ref_afreq

    main:
    ch_versions = Channel.empty()

    scorefiles
        .flatMap { annotate_scorefiles(it) }
        .dump(tag: 'final_scorefiles', pretty: true)
        .set { annotated_scorefiles }
    
    geno
        .mix(pheno, variants)
        .groupTuple(size: 3, sort: true) // sorting is important for annotate_genomic
        .branch {
            ref: it.first().id == 'reference'
            target: it.first().id != 'reference'
        }
        .set { ch_genomes }

    ch_apply_ref = Channel.empty()
    if (params.run_ancestry) {
        // prepare scorefiles for reference data -----------------------------------
        //   1. extract the combined scoring files from the annotated scoring files
        //      (more than one may be present to handle duplicates or effect types)
        //   2. join with a list of variants that intersect
        //   3. combine reference genome with scoring files
        //   3. relabel scoring file IDs from ID_REF -> ID_TARGET
        // assumptions:
        //   - input reference genomes are always combined (i.e. chrom: ALL)
        annotated_scorefiles
            .filter{ it.first().chrom == 'ALL'}
            .map { tuple(it.first().subMap('id'), it) }
            .dump( tag: 'reference_scorefiles', pretty: true)
            .set { ch_ref_scorefile }

        intersection
            .map { tuple( it.first().subMap('id'), it.last() ) }
            .groupTuple()
            .set { ch_grouped_intersections }

        ch_grouped_intersections
            // ref genome must be combined with _all_ scorefiles
            .combine ( ch_ref_scorefile, by: 0 )
        // re-order: [scoremeta, scorefile, [variant match reports]]
            .map { tuple(it.last().first(), it.last().last(), it.tail().head()) }
            .set { ch_scorefile_relabel_input }

        // relabel scoring file ids to match reference format
        RELABEL_SCOREFILES ( ch_scorefile_relabel_input )

        RELABEL_SCOREFILES.out.relabelled
            .transpose()
            .map { annotate_chrom(it) }
            .map { tuple(it.first().subMap('chrom'), it) }
            .set { ch_target_scorefile }

        ch_genomes.ref
            .map { annotate_genomic(it).flatten() }
            .map { tuple(it.first().subMap('chrom'), it) }
            .combine( ch_target_scorefile, by: 0 )
            .map { it.tail().flatten() }
            .set { ch_apply_ref }

        // [meta, file, [matches]]
        ch_grouped_intersections
            .combine( ref_afreq )
            .map{ [it.first(), it.last(), it[1]] }
            .set { ch_afreq }

        // map afreq IDs from reference -> target
        RELABEL_AFREQ ( ch_afreq )
        ref_afreq = RELABEL_AFREQ.out.relabelled
    }

    // intersect genomic data with split scoring files -------------------------
    annotated_scorefiles
        .map { tuple(it.first().subMap('id', 'chrom'), it) }
        .set { ch_target_scorefile }

    ch_genomes.target
        .map { annotate_genomic(it) } // add n_samples
        .map { tuple( it.first().subMap('id', 'chrom'), it ) }
        .combine( ch_target_scorefile, by: 0 )
        .map { it.tail().flatten() }
        .mix( ch_apply_ref ) // add reference genomes!
        .combine( ref_afreq.map { it.last() } ) // add allelic frequencies
        .dump(tag: 'ready_to_score', pretty: true)
        .set { ch_apply }

    PLINK2_SCORE ( ch_apply )
    ch_versions = ch_versions.mix(PLINK2_SCORE.out.versions.first())

    // double check that each scoring file got a calculation result
    scorefile_chroms = annotated_scorefiles.map{ it.first().subMap("chrom", "n", "effect_type") }
    // take unique calculated scores only because scoring files get used for both reference and sampleset 
    // so there can be twice as many calculated scores
    scored_chroms = PLINK2_SCORE.out.scores.map{ it.first().subMap("chrom", "n", "effect_type")}.unique()
    // don't do anything with the result, but do error loudly because score calculations will be affected 
    scorefile_chroms.join(scored_chroms, failOnMismatch: true)

    // [ [meta], [list, of, score, paths] ]
    // subMap ID to keep cache stable across runs
    PLINK2_SCORE.out.scores
        .collect()
        .map { [ it.first().subMap("id"), it.tail().findAll { !(it instanceof LinkedHashMap) }]}
        .set { ch_scores }

    // pgscatalog-aggregate --verify_variants notes:
    // Checks that variant IDs in the scorefiles match the IDs of scored variants perfectly
    // Just dump all of the supporting files into the same directory: don't do any fancy channel manipulation
    PLINK2_SCORE.out.vars_scored
        .collect()
        .set { ch_vars_scored }

    ch_target_scorefile.flatMap { it.last() }
        .filter(Path)
        .collect()
        .set{ ch_target_scorefile_flat }

    // note, for the calculated score:
    // reference_ALL_additive_0.sscore.zst (ch_scores)
    // --verify_variants expects the following files in the same directory
    // reference_ALL_additive_0.sscore.vars (ch_vars_scored)
    // reference_ALL_additive_0.scorefile.gz (ch_verify_scorefiles)

    ch_apply_ref.flatMap { it.last() }
        .filter(Path)
        .mix( ch_target_scorefile_flat )
        .collect()
        .set{ ch_verify_scorefiles }
    
    SCORE_AGGREGATE ( ch_scores, ch_vars_scored, ch_verify_scorefiles )

    ch_versions = ch_versions.mix(SCORE_AGGREGATE.out.versions)

    emit:
    versions = ch_versions
    scores = SCORE_AGGREGATE.out.scores
}

def annotate_scorefiles(ArrayList scorefiles) {
    // INPUT:
    // [[meta], [scorefile_1, ..., scorefile_n]] -> flat list
    // OUTPUT:
    // [[meta], scorefile_1]
    // ...
    // [[meta], scorefile_n]
    // where meta map has been annotated with effect type, chrom, and n_scores
    // the input meta map only contains keys 'id' (dataset ID) and 'is_vcf'

    // firstly, need to associate the scoremeta map with each individual scorefile
    def m = scorefiles.head()
    def scorefile_paths = scorefiles.tail().flatten()
    return [[m], scorefile_paths].combinations()
        // now annotate
        .collect {
            def scoremeta = [:]
            scoremeta.id = it.first().id.toString()

            // add number of scores to a new meta map
            // this is needed because scorefiles may contain different number of
            // scores when split by effect type (e.g. 4 additive scores, 1
            // dominant, 1 recessive). scorefile looks like:
            //     variant ID | effect allele | weight 1 | ... | weight_n
            // one weight is mandatory, extra weight columns are optional
            scoremeta.n_scores = count_scores(it.last().newInputStream())

            // file name structure: {dataset}_{chr}_{effect}_{split}.scorefile -
            // {dataset} is only used to disambiguate files, not for scoremeta
            scoremeta.chrom = it.last().getName().tokenize('_')[1].toString()

            // get effect type from file name of scorefile ---------------------
            scoremeta.effect_type = it.last().getName().tokenize('_')[2]

            // get score number from file name of scorefile ---------------------
            scoremeta.n = it.last().getName().tokenize('_')[3].tokenize('.')[0]

            return [scoremeta, it.last()]
    }
}

def annotate_genomic(ArrayList target) {
    // INPUT:
    // [[meta], [pgen_path, psam_path, pvar_path]]
    // OUTPUT:
    // [[meta], [pgen_path, psam_path, pvar_path]]
    // where meta map has been annotated with n_samples

    def meta = [:].plus(target.first()) 
    meta.id = meta.id.toString()
    meta.chrom = meta.chrom.toString()

    def paths = target.last()
    def sample = paths.collect { it ==~ /.*fam$|.*psam$/ }
    def psam = paths[sample.indexOf(true)]

    def n = -1 // skip header
    psam.eachLine { n++ }
    meta.n_samples = n

    return [meta, paths]
}

def count_scores(InputStream f) {
    // count number of calculated scores in a gzipped plink .scorefile
    // try-with-resources block automatically closes streams
    try (buffered = new BufferedReader(new InputStreamReader(new GZIPInputStream(f)))) {
        def n_extra_cols = 2 // ID, effect_allele
        def n_scores = buffered.readLine().split("\t").length - n_extra_cols
        assert n_scores > 0 : "Counting scores failed, please check scoring file"
        return n_scores
    }
}

def annotate_chrom(ArrayList it) {
    // extract chrom from filename prefix and add to hashmap
    def meta = [:].plus(it.first())
    meta.chrom = it.last().getBaseName().tokenize('_')[1]
    return [meta, it.last()]
}
