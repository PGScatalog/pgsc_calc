//
// Apply a validated scoring file to the QC'd target genomic data
//

include { PLINK2_SCORE }    from '../../modules/local/plink2_score'
include { SCORE_AGGREGATE } from '../../modules/local/score_aggregate'
include { SCORE_REPORT    } from '../../modules/local/score_report'

workflow APPLY_SCORE {
    take:
    geno
    pheno
    variants
    scorefiles
    db // TO DO: improve database..

    main:
    ch_versions = Channel.empty()

    scorefiles
        .flatMap { annotate_scorefiles(it) }
        .dump(tag: 'final_scorefiles')
        .set { annotated_scorefiles }

    // intersect genomic data with split scoring files -------------------------
    geno
        .mix(pheno, variants)
        .groupTuple(size: 3, sort: true) // sorting is important for annotate_genomic
        .map { annotate_genomic(it) }
        .dump( tag: 'final_genomes')
        .cross ( annotated_scorefiles ) { m, it -> [m.id, m.chrom] }
        .map { it.flatten() }
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

    SCORE_REPORT(
        SCORE_AGGREGATE.out.scores,
        Channel.fromPath("$projectDir/bin/report.Rmd", checkIfExists: true),
        Channel.fromPath("$projectDir/assets/PGS_Logo.png", checkIfExists: true),
        db.collect()
    )

    ch_versions = ch_versions.mix(SCORE_REPORT.out.versions)

    emit:
    versions = ch_versions
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
            //     1 score = 2 tab characters, 4 scores = 5
            // one weight is mandatory, extra weight columns are optional
            def n_scores
            it.last().withReader { n_scores = it.readLine().count("\t") - 1 }
            scoremeta.n_scores = n_scores

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
    psam = paths[1] // sorted path input! or we'll count the wrong file
    def n = -1 // skip header
    psam.eachLine { n++ }

    meta.n_samples = n

    return [meta, paths]
}
