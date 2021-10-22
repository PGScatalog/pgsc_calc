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
        .branch {
            vcf: it[0].is_vcf   
            bfile: !it[0].is_vcf
        }
        .set { ch_input } 

    // branch is like a switch statement, so only one bed / bim was being
    // returned
    ch_input.bfile.multiMap { it ->
	bed: [it[0], it[1][0]]
	bim: [it[0], it[1][1]]
	fam: [it[0], it[1][2]]
        }
        .set { ch_bfiles }
        
    emit:
    vcf = ch_input.vcf // channel: [val(meta), path(vcf)]
    bed = ch_bfiles.bed // channel: [val(meta), path(bed)]
    bim = ch_bfiles.bim // channel: [val(meta), path(bim)]
    fam = ch_bfiles.fam // channel: [val(meta), path(fam)]
}

// function to get a list of:
// - [ meta, [vcf_path] ] OR
// - [ meta, [bed_path, bim_path, fam_path] ]
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
	if (!file(row.fam_path).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> fam file does not exist!\n${row.fam_path}"
	}
	if (file(row.bed_path).getBaseName() != row.sample) {
	    exit 1, "ERROR: Please check input samplesheet -> sample id doesn't match bfile base name\n${row.sample} ${row.bed_path}"
	}
        array = [ meta, [ file(row.bed_path), file(row.bim_path), file(row.fam_path) ] ]
    }
    return array
}
