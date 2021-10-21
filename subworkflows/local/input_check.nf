//
// Check input samplesheet and get read channels
//

params.options = [:]

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check' addParams( options: params.options )

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv
   
    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_variant_channel(it) }
        .set { var } 

    var.view()
    
    ch_bed = Channel.empty()
    ch_bim = Channel.empty()
    
    emit:
    vcf = var // channel: [val(meta), path(vcf)]
    bed = ch_bed // channel: [val(meta), path(bed)]
    bim = ch_bim // channel: [val(meta), path(bim)]
}

// function to get a list of:
// - [ meta, [vcf_path] ] OR
// - [ meta, [bed_path, bim_path] ]
def create_variant_channel(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample
    meta.is_vcf       = row.is_vcf.toBoolean()

    def array = []
    if (meta.is_vcf) {
        if (!file(row.vcf_path).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> VCF file does not exist!\n${row.vcf_path}"
	}
	array = [ meta, [ file(row.vcf_path) ] ]
    } else {
        if (!file(row.bed_path).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> bed file does not exist!\n${row.bed_path}"
        }
	if (!file(row.bim_path).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> bim file does not exist!\n${row.bim_path}"
	}
        array = [ meta, [ file(row.bed_path), file(row.bim_path) ] ]
    }
    return array
}
