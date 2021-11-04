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

println params.validate_extract_options

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    PLINK2_RELABEL ( bed, bim, fam )

    PLINK2_EXTRACT (
        PLINK2_RELABEL.out.pgen,
        PLINK2_RELABEL.out.psam,
        PLINK2_RELABEL.out.pvar,
        scorefile.flatten().last() // just the file, not the meta map
    )

    VALIDATE_EXTRACT (
        PLINK2_EXTRACT.out.pvar.flatten().last(),
        scorefile.flatten().last(),
        file("$projectDir/bin/check_extract.awk")
    )

    PLINK2_RELABEL.out.versions
        .mix(PLINK2_EXTRACT.out.versions)
        .mix(VALIDATE_EXTRACT.out.versions)
        .set { ch_versions }

    emit:
    pgen = PLINK2_EXTRACT.out.pgen
    psam = PLINK2_EXTRACT.out.psam
    pvar = PLINK2_EXTRACT.out.pvar
    scorefile = VALIDATE_EXTRACT.out.scorefile
    versions = ch_versions
}
