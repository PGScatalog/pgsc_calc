//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos) (PLINK2_RELABEL)
//     - Intersecting variants by position (PLINK2_EXTRACT)
//     - Validate intersection overlaps well and fix strand issues (VALIDATE_EXTRACT)
//

params.validate_extract_options = [:]

include { PLINK2_RELABEL  } from '../../modules/local/plink2_relabel'  addParams ( options: [:] )
include { PLINK2_EXTRACT  } from '../../modules/local/plink2_extract'  addParams ( options: [suffix:'.extract'] )
include { COMBINE_BIM     } from '../../modules/local/combine_bim'     addParams ( options: [:] )
include { CHECK_OVERLAP   } from '../../modules/local/check_overlap'   addParams ( options: params.validate_extract_options )
include { SCOREFILE_QC    } from '../../modules/local/scorefile_qc'    addParams ( options: [:] )
include { SCOREFILE_SPLIT } from '../../modules/local/scorefile_split' addParams ( options: [:] )

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    ch_versions = Channel.empty()

    PLINK2_RELABEL (
        bed
            .mix(bim, fam)
            .groupTuple()
            .map { it.flatten() }
    )

    SCOREFILE_QC(scorefile)

    // -------------------------------------------------------------------------
    // Recombine split bim files to check the overlap between target variants
    // and scorefile variants (plink2 pvar == plink1 bim)
    //
    // Why split then recombine? It's easiest to do now, because all files are
    // guaranteed to be split at this stage even with mixed input. The order of
    // the combined bim file isn't preserved but it's not necessary for the awk
    // program in CHECK_OVERLAP. The final scorefile is sorted in CHECK_OVERLAP.
    COMBINE_BIM (
        PLINK2_RELABEL.out.pvar
            .map { [it.head().take(2), it.tail()] } // drop chrom from meta for groupTuple
            .groupTuple()
            .map{ [it.head(), it.tail().flatten()] } // [[meta], [pvar1, ..., pvarn]]
    )

    CHECK_OVERLAP (
        // overlap should be checked once per sample
        // [[meta], combined_pvar, [scoremeta], scorefile]
        COMBINE_BIM.out.variants
            .combine(SCOREFILE_QC.out.data)
    )
    )

    PLINK2_RELABEL.out.versions
//        .mix(VALIDATE_EXTRACT.out.versions)
        .set { ch_versions }

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = CHECK_OVERLAP.out.scorefile
    versions = ch_versions
}
