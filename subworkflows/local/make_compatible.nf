//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos) (PLINK2_RELABEL)
//     - Match variants across scorefile and target data, flipping if necessary
//

include { PLINK2_VCF      } from '../../modules/nf-core/modules/plink2/vcf/main'

include { PLINK2_RELABEL  } from '../../modules/local/plink2_relabel'
include { MATCH_VARIANTS  } from '../../modules/local/match_variants'

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    vcf
    scorefile

    main:
    ch_versions = Channel.empty()

    PLINK2_VCF(vcf)
    ch_versions = ch_versions.mix(PLINK2_VCF.out.versions.first())

    bed
        .mix(bim, fam)
        .groupTuple(size: 3, sort: true)
        .map { it.flatten() }
        .set { pfiles }

    PLINK2_RELABEL( pfiles )
    ch_versions = ch_versions.mix(PLINK2_RELABEL.out.versions.first())

    pgen = PLINK2_RELABEL.out.pgen.mix(PLINK2_VCF.out.pgen)
    psam = PLINK2_RELABEL.out.psam.mix(PLINK2_VCF.out.psam)
    pvar = PLINK2_RELABEL.out.pvar.mix(PLINK2_VCF.out.pvar)

    // Recombine any split variant information files to match target variants
    // and scorefile variants (plink2 pvar == plink1 bim)
    pvar.map { [it.head().take(2), it.tail()] } // drop chrom from meta for groupTuple
        .groupTuple()
        .map { [it.head(), it.tail().flatten()] } // [[meta], [pvar1, ..., pvarn]]
        .set { flat_bims }

    // variants should be matched once per sample identifier
    // [[meta], combined_pvar, [scoremeta], scorefile]
    MATCH_VARIANTS ( flat_bims.combine(scorefile) )
    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = MATCH_VARIANTS.out.scorefile
    versions = ch_versions
}
