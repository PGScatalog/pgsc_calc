//
// Apply a validated scoring file to the QC'd target genomic data
//

include { PLINK2_SCORE } from '../../modules/local/plink2_score' addParams ( options: [:] )

workflow APPLY_SCORE {
    take:
    pgen
    psam
    pvar
    scorefile

    main:
    // TODO: support multiple scorefiles
    PLINK2_SCORE (
        pgen
            .mix(psam, pvar)
            .groupTuple(size: 3)
            .map{ it.flatten() },
        scorefile
    )

   PLINK2_SCORE.out.versions
       .set { ch_versions }

   emit:
   score = PLINK2_SCORE.out.score
   versions = ch_versions
}
