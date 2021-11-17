//
// Apply a validated scoring file to the QC'd target genomic data
//

include { PLINK2_SCORE } from '../../modules/local/plink2_score' addParams ( options: [:] )

workflow APPLY_SCORE {
    take:
    pgen // [[id: 1, is_vcf: true, chrom: 21], path(pgen)]
    psam // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    pvar // [[id: 1, is_vcf: true, chrom: 21], path(pvar)]
    scorefile // [[id: 1, accession:PGS001229, chrom:21], path(scorefile)]

    main:
    ch_versions = Channel.empty()

    pgen
        .mix(psam, pvar)
        .groupTuple(size: 3, sort: true) // alphabetical  pgen, psam, pvar is nice
        .cross ( scorefile ) { [it.first().id, it.first().chrom] }
        .map{ it.flatten() }  // [[meta], pgen, psam, pvar, [scoremeta], scorefile]
        .set { ch_apply } // data to apply scores to

    PLINK2_SCORE (
        ch_apply
    )

    // combine scores now per sample...

//   PLINK2_SCORE.out.versions
//       .set { ch_versions }

   emit:
   score = PLINK2_SCORE.out.score
   versions = ch_versions
}

// A function to update a scoremeta with sample ID
//     [[id:1], [scoremeta], scorefile]
