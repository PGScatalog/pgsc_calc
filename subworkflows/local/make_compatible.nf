//
// Make the scoring file compatible with the target genomic data by:
//     - Using a consistent variant labelling format (chr:pos) (PLINK2_RELABEL)
//     - Match variants across scorefile and target data, flipping if necessary
//

include { PLINK2_RELABEL  } from '../../modules/local/plink2_relabel'
include { PLINK2_EXTRACT  } from '../../modules/local/plink2_extract'
include { COMBINE_BIM     } from '../../modules/local/combine_bim'
include { MATCH_VARIANTS  } from '../../modules/local/match_variants'
include { SCOREFILE_QC    } from '../../modules/local/scorefile_qc'
include { SCOREFILE_SPLIT } from '../../modules/local/scorefile_split'

workflow MAKE_COMPATIBLE {
    take:
    bed
    bim
    fam
    scorefile

    main:
    ch_versions = Channel.empty()

    bed
        .mix(bim, fam)
        .groupTuple(size: 3, sort: true)
        .map { it.flatten() }
        .set { pfiles }

    PLINK2_RELABEL( pfiles )

    ch_versions = ch_versions.mix(PLINK2_RELABEL.out.versions.first())

    SCOREFILE_QC( scorefile )

    ch_versions = ch_versions.mix(SCOREFILE_QC.out.versions.first())

    // -------------------------------------------------------------------------
    // Recombine split bim files to check the overlap between target variants
    // and scorefile variants (plink2 pvar == plink1 bim)
    //
    // Why split then recombine? It's easiest to do now, because all files are
    // guaranteed to be split at this stage even with mixed input. The order of
    // the combined bim file isn't preserved but it's not necessary for the awk
    // program in CHECK_OVERLAP. The final scorefile is sorted in CHECK_OVERLAP.
    PLINK2_RELABEL.out.pvar
        .map { [it.head().take(2), it.tail()] } // drop chrom from meta for groupTuple
        .groupTuple()
        .map { [it.head(), it.tail().flatten()] } // [[meta], [pvar1, ..., pvarn]]
        .set { flat_bims }

    COMBINE_BIM( flat_bims )

    ch_versions = ch_versions.mix(COMBINE_BIM.out.versions)

    MATCH_VARIANTS (
        // variants should be matched once per sample
        // [[meta], combined_pvar, [scoremeta], scorefile]
        COMBINE_BIM.out.variants
            .combine(SCOREFILE_QC.out.data)
    )

    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    SCOREFILE_SPLIT (
        // scorefile split should only happen once per unique accession
        MATCH_VARIANTS.out.scorefile
            .unique { it.head().accession },
        "chromosome"
    )

    ch_versions = ch_versions.mix(SCOREFILE_SPLIT.out.versions.first())

    // generate a list of chromosome split scorefile - sampleID combinations ---
    // then emit a flat list of split scorefiles
    PLINK2_RELABEL.out.pgen
        .map { it.head().take(1) }
        .unique { it.id } // unique flat list of sample IDs [id:1], [id:n]
        .combine(SCOREFILE_SPLIT.out.scorefile) // [[meta], [scoremeta], [[split_score_1], ...]]
        .flatMap { create_scorefile_channel([it[0] << it[1], it[2]]) } // combine meta and scoremeta
        .set { ch_scorefile } // flat list [[accession:PGS001229, chrom: 22, id: 1], scorefile]

    emit:
    pgen = PLINK2_RELABEL.out.pgen
    psam = PLINK2_RELABEL.out.psam
    pvar = PLINK2_RELABEL.out.pvar
    scorefile = ch_scorefile
    versions = ch_versions
}

// function to get a list of sample-chromosome combinations:
// [[meta], 22.keep, ..., n.keep] -> [[[meta], 22.keep], [[meta], n.keep]]]
def create_scorefile_channel(ArrayList chrom) {
    meta = chrom.head()
    variant_files = chrom.tail().flatten()
    combs = [[meta], variant_files].combinations()
    // now add chr label to meta map using basename of variant keep file
    // the variant keep file takes its name from the CHROM column of the VCF
    combs.collect { m, it ->
        def chrom_map = [:]
        chrom_map.chrom = (it.getName() - ~/\.\w+$/) // removes file extension
        [m + chrom_map, it].flatten()
    }
}
