//
// Check input samplesheet and get read channels
//

params.options = [:]

// TODO: should we even use a samplesheet?
// include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check' addParams( options: params.options )

workflow INPUT_CHECK {
    take:
    input
    format

    main:
    is_vcf_input = format.equals("vcf")

    if (is_vcf_input) {
        extension = "*.vcf.gz"
        ch_vcf = Channel.fromPath(input + extension, checkIfExists: true)
	ch_bed = Channel.empty()
        ch_bim = Channel.empty()

	ch_vcf.subscribe {
            if ( "$it".endsWith(".bed") ) exit 1, "Are you sure you provided a VCF file? Bad input: $it"
            if ( "$it".endsWith(".bim") ) exit 1, "Are you sure you provided a VCF file? Bad input: $it"
        }

    } else {
        ch_vcf = Channel.empty()
	ch_bed = Channel.fromPath(input + "*.bed", checkIfExists: true)
	ch_bim = Channel.fromPath(input + "*.bim", checkIfExists: true)

        ch_bed.mix(ch_bim).subscribe {
	    if ( "$it".endsWith(".vcf.gz") ) exit 1, "Are you sure you have a bfile? Bad input: $it"
	    if ( "$it".endsWith(".vcf") ) exit 1, "Are you sure you have a bfile? Bad input: $it"
        }

    }

    ch_vcf
        .map { vcf ->
            def meta = [:]
	    meta.id = vcf.baseName
	    [meta, vcf] }
	.set{ ch_vcf }

    ch_bed
        .map { bfile ->
            def meta = [:]
	        meta.id = bfile.baseName
	        [meta, bfile] }
    	.set{ ch_bed }

    ch_bim
        .map { bfile ->
            def meta = [:]
	        meta.id = bfile.baseName
	        [meta, bfile] }
    	.set{ ch_bim }

    emit:
    vcf = ch_vcf // channel: [val(meta), path(vcf)]
    bed = ch_bed // channel: [val(meta), path(bed)]
    bim = ch_bim // channel: [val(meta), path(bim)]
}
