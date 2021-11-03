//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos)
//     - Intersecting variants
//     - Fixing strand issues
//

params.check_extract_options = [:]

include { PLINK2_RELABEL } from '../../modules/local/plink2_relabel' addParams ( options: [:] )
include { PLINK2_EXTRACT } from '../../modules/local/plink2_extract' addParams ( options: [suffix:'.extract'] )
include { CHECK_EXTRACT } from '../../modules/local/check_extract' addParams ( options: params.check_extract_options )

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

    CHECK_EXTRACT (
        PLINK2_EXTRACT.out.pvar.flatten().last(),
        scorefile.flatten().last(),
        file("$projectDir/bin/check_extract.awk")
    )
    // PLINK2_FIXSTRAND

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = scorefile
    versions = Channel.empty()
}
