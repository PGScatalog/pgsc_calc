//
// Check input samplesheet and get read channels
//

def modules = params.modules.clone()
params.options = [:]

include { SAMPLESHEET_CHECK              } from '../../modules/local/samplesheet_check'            addParams( options: params.options )
include { SCOREFILE_CHECK                } from '../../modules/local/scorefile_check'              addParams( options: params.options )
include { PLINK_VCF                      } from '../../modules/nf-core/modules/plink/vcf/main'     addParams( options: modules['plink_vcf'] )


workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv
    scorefile // tuple val(id), path(/path/to/score_file)

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

    PLINK_VCF (
        ch_input.vcf
    )

    // branch is like a switch statement, so only one bed / bim was being
    // returned
    ch_input.bfile.multiMap { it ->
        bed: [it[0], it[1][0]]
        bim: [it[0], it[1][1]]
        fam: [it[0], it[1][2]]
        }
        .set { ch_bfiles }

    SCOREFILE_CHECK ( scorefile )

    SAMPLESHEET_CHECK.out.versions
        .mix(SCOREFILE_CHECK.out.versions)
        .set{ ch_versions }

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

    if (! file(row.datadir).exists())_{
        exit 1, "ERROR: Please check input samplesheet -> data directory doesn't exist!"
    }

    // todo: better way of joining files?
    bed_path = file(row.datadir + "/" + row.bfile_prefix + ".bed")
    bim_path = file(row.datadir + "/" + row.bfile_prefix + ".bim")
    fam_path = file(row.datadir + "/" + row.bfile_prefix + ".fam")
    vcf_path = file(row.datadir + "/" + row.vcf_path)

    def array = []
    if (meta.is_vcf) {
        if (!vcf_path.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> VCF file does not exist!\n${row.vcf_path}"
        }
        array = [ meta, [ vcf_path ] ]
    } else {
        if (!bed_path.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> bed file does not exist!\n${bed_path}"
        }
        if (!bim_path.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> bim file does not exist!\n${bim_path}"
        }
        if (!fam_path.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> fam file does not exist!\n${fam_path}"
        }
        if (bed_path.getBaseName() != row.sample) {
            exit 1, "ERROR: Please check input samplesheet -> sample id doesn't match bfile base name\n${row.sample} ${bed_path}"
        }
        array = [ meta, [ bed_path, bim_path, fam_path ] ]
    }
    return array
}

