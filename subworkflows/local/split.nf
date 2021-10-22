//
// Split input file into smaller chunks (typically chromosome)
//

params.options = [:]

include { SPLIT_BIM } from '../../modules/local/split_bim' addParams (options: [:] )

// TODO: submit to nf-core
include { PLINK_EXTRACT } from '../../modules/local/plink_extract' addParams (options: [:] )

workflow SPLIT {
    take:
    bed
    bim
    fam
    split_method // chromosome or chunk

    main:
    SPLIT_BIM(bim, split_method)
    PLINK_EXTRACT(bed, bim, fam, SPLIT_BIM.out.variants)
}
