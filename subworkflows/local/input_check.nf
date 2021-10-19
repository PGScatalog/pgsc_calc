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
	ch_bfile = Channel.empty()
    } else {
        ch_vcf = Channel.empty()
	ch_bed = Channel.fromPath(input + "*.bed", checkIfExists: true)
	ch_bim = Channel.fromPath(input + "*.bim", checkIfExists: true)
	ch_bfile = ch_bed.concat(ch_bim)
    }

    // Check that inputs didn't get mixed up
    ch_bfile
        .subscribe {
	    if ( "$it".endsWith(".vcf.gz") ) exit 1, "Are you sure you have a bfile? Bad input: $it"
	    if ( "$it".endsWith(".vcf") ) exit 1, "Are you sure you have a bfile? Bad input: $it"
        }

    ch_vcf
        .subscribe {
            if ( "$it".endsWith(".bed") ) exit 1, "Are you sure you provided a VCF file? Bad input: $it"
            if ( "$it".endsWith(".bim") ) exit 1, "Are you sure you provided a VCF file? Bad input: $it"
        }

    ch_vcf
        .map { vcf ->
            def meta = [:]
	    meta.id = vcf.baseName
	    [meta, vcf] }
	.set{ ch_vcf }

    ch_bfile
        .map { bfile ->
     	    def meta = [:]
	    meta.id = bfile.baseName
	    meta.extension = bfile.Extension
	    [meta, bfile] }
	.set{ ch_bfile }

    emit:
    vcf = ch_vcf // channel: [val(meta), path(vcf)]
    bfile = ch_bfile // channel: [val(meta), path(bfile)]
}
