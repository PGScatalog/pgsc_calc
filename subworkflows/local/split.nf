//
// Split input file into smaller chunks (typically chromosome)
//

params.options = [:]

include { SPLIT_BIM } from '../../modules/local/split_bim' addParams (options: [:] )

// TODO: submit to nf-core
include { PLINK_KEEP } from '../../modules/local/plink_keep' addParams (options: [:] )

workflow SPLIT {
    take:
    bed
    bim
    split_method // chromosome or chunk

    main:
    SPLIT_BIM(bim, split_method)
    // TODO: some channel stuff - tuple of meta, chromosome, and path?
    
    //PLINK_KEEP(input, variants)
}
