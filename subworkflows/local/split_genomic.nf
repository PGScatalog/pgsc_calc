//
// Split input file into smaller chunks (typically chromosome)
//

params.options = [:]

include { SPLIT_BIM as SPLIT_CHROM       } from '../../modules/local/split_bim'                    addParams( options: params.options )
include { SPLIT_BIM as SPLIT_SCOREFILE   } from '../../modules/local/split_bim'                    addParams( options: params.options )
include { PLINK_EXTRACT as EXTRACT_CHROM } from '../../modules/nf-core/modules/plink/extract/main' addParams( options: [suffix:'.extract'] )

workflow SPLIT_GENOMIC {
    take:
    bed
    bim
    fam
    scorefile

    main:
    // Split bim if [chrom:false] ----------------------------------------------
    bim
        .branch {
            to_split: !it.first().chrom
            splat: it.first().chrom // chrom set in samplesheet
        }
        .set { ch_split }

    SPLIT_CHROM (
        ch_split.to_split,
        "chromosome"
    )

    // [meta1, chrom1, chromN] -> [meta1, chrom1]
    //                            [meta1, chromN]
    SPLIT_CHROM.out.variants
        .flatMap { create_chrom_channel(it) }
        .set { ch_sample_chrom }

    // Use split bim on bfiles -------------------------------------------------

    // first combine all the genomic data that needs split into a flat list of:
    //     [meta1, bed, bim, fam]
    //     [metaN, bed, bim, fam]
    bed
        .mix(bim, fam)
        .groupTuple(size: 3)
        .map{ it.flatten() }
    // cross notes:
    //     source identifier must be unique (this is OK for files that need split).
    //     mapping function matches by ID only because map is missing chrom in bed / fam.
    // TODO: what happens if somebody provides null chr + multiple ID? we should error
        .cross(ch_sample_chrom) { it -> it.head().id }
        .map { create_plink_extract_channel(it) }
        .set { ch_plink_extract }

    // [meta, bed, bim, fam, variants]
    EXTRACT_CHROM { ch_plink_extract }

    // Now mix split files with pre-split files --------------------------------
    ch_split.splat
        .join(bed)
        .join(fam)
        .multiMap {
            bed: [it[0], it[1]]
            bim: [it[0], it[2]]
            fam: [it[0], it[3]]
        }
        .set { ch_bfiles_splat } // all bfiles that don't need to be split

    // Split scorefile by chrom ------------------------------------------------
    SPLIT_SCOREFILE(scorefile, "chromosome")

    // now get a flat list like:
    //     [[id:PGS001229, chrom: 22], scorefile]
    SPLIT_SCOREFILE.out.variants
        .flatMap { create_chrom_channel(it) }
        .set { ch_scorefiles }

    emit:
    bed = ch_bfiles_splat.bed.mix( EXTRACT_CHROM.out.bed )
    bim = ch_bfiles_splat.bim.mix( EXTRACT_CHROM.out.bim )
    fam = ch_bfiles_splat.fam.mix( EXTRACT_CHROM.out.fam )
    scorefile = ch_scorefiles
}

// function to get a list of sample-chromosome combinations:
// [[meta], 22.keep, ..., n.keep] -> [[[meta], 22.keep], [[meta], n.keep]]]
// where each keep file is used to extract variants with plink
def create_chrom_channel(ArrayList chrom) {
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

// function to get a list of genomic data + variants to be extracted for PLINK_EXTRACT
// input:
//     cross() returns a nested list like:
//     [[meta], bed, bim, fam], [[[meta], variant_file]]]
// where the first meta map is missing chrom information from the second meta
// expected output:
//     [[meta], bed, bim, fam, variants_file]
def create_plink_extract_channel(ArrayList it) {
    meta = it.tail().flatten().head()
    bfiles = it.head().tail()
    variant_file = it.tail().flatten().tail()
    [meta, bfiles, variant_file].flatten()
}
