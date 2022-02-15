//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos) (PLINK2_RELABEL)
//     - Match variants across scorefile and target data, flipping if necessary
//

include { PLINK2_VCF     } from '../../modules/nf-core/modules/plink2/vcf/main'

include { PLINK2_BFILE   } from '../../modules/local/plink2_bfile'
include { MATCH_VARIANTS } from '../../modules/local/match_variants'

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

    PLINK2_BFILE( pfiles )
    ch_versions = ch_versions.mix(PLINK2_BFILE.out.versions.first())

    pgen = PLINK2_BFILE.out.pgen.mix(PLINK2_VCF.out.pgen)
    psam = PLINK2_BFILE.out.psam.mix(PLINK2_VCF.out.psam)
    pvar = PLINK2_BFILE.out.pvar.mix(PLINK2_VCF.out.pvar)

    // Recombine split variant information files to match target variants ------

    // custom groupKey() to set a different group size for each sample ID
    // different samples may have different numbers of chromosomes
    // see https://nextflow.io/docs/latest/operator.html#grouptuple
    // if a size is not provided then nextflow must wait for the entire process
    // to finish before releasing the grouped tuples, which can be very slow(!)
    pvar.map { tuple(groupKey(it[0].subMap(['id', 'is_vcf']), it[0].n_chrom),
                     it[0].chrom, it[1]) }
        .groupTuple()
        .set { flat_bims }

    // variants should be matched once per sample identifier
    MATCH_VARIANTS ( flat_bims.combine(scorefile) )
    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    emit:
    pgen
    psam
    pvar
    scorefile = MATCH_VARIANTS.out.scorefile
    versions = ch_versions
}
