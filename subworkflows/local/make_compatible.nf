//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos)
//     - Intersecting variants
//     - Fixing strand issues
//

// WEIRD ISSUES:
// comm <(awk 'NR == 1 {next} {print $3}' synthetic.extract.pvar | sort) <(awk -F: 'BEGIN{OFS=":"} $1==22 { print $1,$2 }' variants.txt | sort) -3
//      22:32756652
//      22:47986332
// 2 variants in scoring file but not in extracted output...
// but they are just missing from the original genetic data, OK

params.options = [:]

include { PLINK2_RELABEL } from '../../modules/local/plink2_relabel' addParams ( options: [:] )
include { PLINK2_EXTRACT } from '../../modules/local/plink2_extract' addParams ( options: [suffix:'.extract'] )
include { CHECK_EXTRACT } from '../../modules/local/check_extract' addParams ( options: [:] )

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    PLINK2_RELABEL ( bed, bim, fam )
    scorefile.view()
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
