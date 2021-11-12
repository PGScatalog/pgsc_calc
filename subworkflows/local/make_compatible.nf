//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos) (PLINK2_RELABEL)
//     - Intersecting variants by position (PLINK2_EXTRACT)
//     - Validate intersection overlaps well and fix strand issues (VALIDATE_EXTRACT)
//

params.validate_extract_options = [:]

include { PLINK2_RELABEL } from '../../modules/local/plink2_relabel' addParams ( options: [:] )
include { PLINK2_EXTRACT } from '../../modules/local/plink2_extract' addParams ( options: [suffix:'.extract'] )
include { VALIDATE_EXTRACT } from '../../modules/local/validate_extract' addParams ( options: params.validate_extract_options )
include { SCOREFILE_QC } from '../../modules/local/scorefile_qc'

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    PLINK2_RELABEL (
        bed
            .mix(bim, fam)
            .groupTuple()
            .map { it.flatten() }
    )

    // TODO: fix this too to work with multiple files
    SCOREFILE_QC(scorefile)

    // TODO: this is broken with big filesssssssssssssssssss
    VALIDATE_EXTRACT (
        PLINK2_RELABEL.out.pvar.flatten().last(),
        SCOREFILE_QC.out.data.flatten().last(),
        file("$projectDir/bin/check_extract.awk")
    )

    PLINK2_RELABEL.out.versions
//        .mix(VALIDATE_EXTRACT.out.versions)
        .set { ch_versions }

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = VALIDATE_EXTRACT.out.scorefile // to do [[meta], file]
    versions = ch_versions
}
