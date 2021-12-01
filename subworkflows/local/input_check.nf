//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'
include { SCOREFILE_CHECK   } from '../../modules/local/scorefile_check'
include { PLINK_VCF         } from '../../modules/nf-core/modules/plink/vcf/main'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv
    scorefile // tuple val(id), path(/path/to/score_file)

    main:
    ch_versions = Channel.empty()

    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_variant_channel(it) }
        .branch {
            vcf: it[0].is_vcf
            bfile: !it[0].is_vcf
        }
        .set { ch_input }
    ch_versions = ch_versions.mix(SAMPLESHEET_CHECK.out.versions)

    PLINK_VCF (
        ch_input.vcf
    )
    ch_versions = ch_versions.mix(PLINK_VCF.out.versions.first())

    // branch is like a switch statement, so only one bed / bim was being
    // returned
    ch_input.bfile.multiMap { it ->
        bed: [it[0], it[1][0]]
        bim: [it[0], it[1][1]]
        fam: [it[0], it[1][2]]
    }
        .set { ch_bfiles }

    SCOREFILE_CHECK ( scorefile )
    ch_versions = ch_versions.mix(SCOREFILE_CHECK.out.versions.first())

    emit:
    bed = ch_bfiles.bed.mix(PLINK_VCF.out.bed) // channel: [val(meta), path(bed)]
    bim = ch_bfiles.bim.mix(PLINK_VCF.out.bim) // channel: [val(meta), path(bim)]
    fam = ch_bfiles.fam.mix(PLINK_VCF.out.fam) // channel: [val(meta), path(fam)]
    scorefile = SCOREFILE_CHECK.out.data
    versions = ch_versions
}

// function to get a list of:
// - [ meta, [vcf_path] ] OR
// - [ meta, [bed_path, bim_path, fam_path] ]
def create_variant_channel(LinkedHashMap row) {
    def meta    = [:]
    meta.id     = row.sample
    meta.is_vcf = row.is_vcf.toBoolean()
    meta.chrom  = row.chrom?: false

    if (row.datadir) {
        if (! file(row.datadir).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> data directory doesn't exist!"
        }
    }

    def array = []
    if (meta.is_vcf) {
        vcf_path = array_to_file([row.datadir, row.vcf_path])
        array = [ meta, [ vcf_path ] ]
    } else {
        bed_path = array_to_file([row.datadir, row.bfile_prefix + ".bed"])
        bim_path = array_to_file([row.datadir, row.bfile_prefix + ".bim"])
        fam_path = array_to_file([row.datadir, row.bfile_prefix + ".fam"])
        array = [ meta, [ bed_path, bim_path, fam_path ] ]
    }
    return array
}

// given an array of strings, return a file object
def array_to_file(ArrayList x) {
    x.removeAll(["", null]) // datadir may be null, don't convert to an absolute with join
    try {
        return file(x.join("/"), checkIfExists: true)
    } catch(IOException e) {
        // point the user to the samplesheet
        throw new IOException("ERROR: Please check input samplesheet " +
                              "-> file ${x.join('/')} does not exist\n" +
                              "(did you correctly specify datadir column?)")
    }
}
