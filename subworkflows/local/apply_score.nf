//
// Apply a validated scoring file to the QC'd target genomic data
//
import java.util.zip.GZIPInputStream

include { RELABEL_IDS as RELABEL_SCOREFILE_IDS; RELABEL_IDS as RELABEL_AFREQ_IDS } from '../../modules/local/ancestry/relabel_ids'
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
        .dump(tag: 'final_scorefiles')
        .set { annotated_scorefiles }

    geno
        .mix(pheno, variants)
        .groupTuple(size: 3, sort: true) // sorting is important for annotate_genomic
        .branch {
            ref: it.first().id == 'reference'
            target: it.first().id != 'reference'
        }
        .set { ch_all_genomes }

    ch_all_genomes.target.set { ch_genomes }

    ch_apply_ref = Channel.empty()
    if (!params.skip_ancestry) {
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
            .set { ch_ref_scorefile }

        intersection
            .map { tuple( it.first().subMap('id'), it.last() ) }
            .groupTuple() // TODO: be polite and set size
            .set { ch_grouped_intersections }

        ch_grouped_intersections
            // ref genome must be combined with _all_ scorefiles
            .combine ( ch_ref_scorefile, by: 0 )
            // re-order: [scoremeta, [variant match reports], scorefile]
            .map { tuple(it.last().first(), it.tail().head(), it.last().last()) }
            .set { ch_scorefile_relabel_input }

        // relabel scoring file ids to match reference format
        RELABEL_SCOREFILE_IDS ( ch_scorefile_relabel_input )

        RELABEL_SCOREFILE_IDS.out.relabelled
            .transpose()
            .map { annotate_chrom(it) }
            .map { tuple(it.first().subMap('chrom'), it) }
            .set { ch_target_scorefile }

        ch_all_genomes.ref
            .map { annotate_genomic(it).flatten() }
            .map { tuple(it.first().subMap('chrom'), it) }
            .combine( ch_target_scorefile, by: 0 ) // to work with multiple samplesets
            .map { it.tail().flatten() }
            .set { ch_apply_ref }

        ch_grouped_intersections
            .combine( ref_afreq.map{ it.last() } )
            .set { ch_afreq }

        // map afreq IDs from reference -> target
        RELABEL_AFREQ_IDS ( ch_afreq )
        ref_afreq = RELABEL_AFREQ_IDS.out.relabelled
    }

    // intersect genomic data with split scoring files -------------------------
    ch_genomes
        .map { annotate_genomic(it) }
        .dump( tag: 'final_genomes')
        .cross ( annotated_scorefiles ) { m, it -> [m.id, m.chrom] }
        .map { it.flatten() }
        .mix( ch_apply_ref ) // add reference genomes!
        .combine( ref_afreq.map { it.last() } ) // add allelic frequencies
        .dump(tag: 'ready_to_score')
        .set { ch_apply }

    // make sure the workflow tries to process at least one score, or explode
    def score_fail = true
    ch_apply.subscribe onNext: { score_fail = false }, onComplete: { score_error(score_fail) }

    PLINK2_SCORE ( ch_apply )

    ch_versions = ch_versions.mix(PLINK2_SCORE.out.versions.first())

    PLINK2_SCORE.out.scores
        .collect()
        .set { ch_scores }

    SCORE_AGGREGATE ( ch_scores )

    ch_versions = ch_versions.mix(SCORE_AGGREGATE.out.versions)

    emit:
    versions = ch_versions
    scores = SCORE_AGGREGATE.out.scores
}

def score_error(boolean fail) {
    if (fail) {
        log.error "ERROR: No scores calculated!"
        System.exit(1)
    } else {
        log.info "INFO: Scores ready for calculation"
    }
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
    scoremeta = scorefiles.head()
    scorefile_paths = scorefiles.tail().flatten()
    return [[scoremeta], scorefile_paths].combinations()
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
            scoremeta.n_scores = count_scores(it.last())

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
    // cloning is important or original instance will also be edited

    meta = target.first().clone()
    meta.id = meta.id.toString()
    meta.chrom = meta.chrom.toString()

    paths = target.last()
    sample = paths.collect { it ==~ /.*fam$|.*psam$/ }
    psam = paths[sample.indexOf(true)]

    def n = -1 // skip header
    psam.eachLine { n++ }
    meta.n_samples = n

    return [meta, paths]
}

def count_scores(Path f) {
    // count number of calculated scores in a gzipped plink .scorefile
    // try-with-resources block automatically closes streams
    try (buffered = new BufferedReader(new InputStreamReader(new GZIPInputStream(new FileInputStream(f.toFile()))))) {
        n_extra_cols = 2 // ID, effect_allele
        n_scores = buffered.readLine().split("\t").length - n_extra_cols
        assert n_scores > 0 : "Counting scores failed, please check scoring file"
        return n_scores
    }
}

// TODO: turn this into a utility function
def annotate_chrom(ArrayList it) {
    // extract chrom from filename prefix and add to hashmap
    meta = it.first().clone()
    meta.chrom = it.last().getBaseName().tokenize('_')[1]
    return [meta, it.last()]
}
