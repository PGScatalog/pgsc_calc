//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos)
//     - Intersecting variants
//     - Fixing strand issues
//

params.options = [:]

include { PLINK2_RELABEL } from '../../modules/local/plink2_relabel' addParams ( options: [:] )

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    PLINK2_RELABEL ( bed, bim, fam )
    // PLINK2_INTERSECT
    // PLINK2_FIXSTRAND

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = scorefile
    versions = Channel.empty()
}
