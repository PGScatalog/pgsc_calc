//
// Split input file into smaller chunks (typically chromosome)
//

params.options = [:]

include { MAWK_SPLITBIM } from '../../modules/local/mawk_splitbim' addParams (options: [:] )

// TODO: submit to nf-core
include { PLINK_EXTRACT } from '../../modules/local/plink_extract' addParams (options: [:] )

workflow SPLIT {
    take:
    bed
    bim
    fam
    split_method // chromosome or chunk

    main:
    MAWK_SPLITBIM(bim, split_method)

    // I need to combine 4 paths with a meta key for PLINK_EXTRACT
    // the best thing to do is to build the channel like:
    // ch1 - meta, bed, bim, fam
    // ch2 - meta, variants
    // linked by meta key to make sure variants files match the correct sample
    bed
	.join(bim)
	.join(fam)
	.combine(MAWK_SPLITBIM.out.variants)
	.view()
    // this looks good but makes one long list! how to separate them?
	
    // PLINK_EXTRACT(bed, bim, fam, MAWK_SPLITBIM.out.variants)
}
