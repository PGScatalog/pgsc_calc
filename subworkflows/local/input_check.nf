//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_JSON } from '../../modules/local/samplesheet_json'
include { SCOREFILE_CHECK  } from '../../modules/local/scorefile_check'
include { PLINK_VCF        } from '../../modules/nf-core/modules/plink/vcf/main'

workflow INPUT_CHECK {
    take:
    input // file: /path/to/samplesheet.csv
    format // csv or JSON
    scorefile // tuple val(id), path(/path/to/score_file)

    main:
    ch_versions = Channel.empty()

    if (format.equals("csv")) {
        SAMPLESHEET_JSON(input)
        ch_versions = ch_versions.mix(SAMPLESHEET_JSON.out.versions)
        SAMPLESHEET_JSON.out.json
            .map { json_slurp(it) }
            .branch {
                vcf: it[0].is_vcf
                bfile: !it[0].is_vcf
            }
            .set { ch_input }
    } else if (format.equals("json")) {
        Channel.from(input)
            .map { json_slurp(it) }
            .branch {
                vcf: it[0].is_vcf
                bfile: !it[0].is_vcf
            }
            .set { ch_input }
    }

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

def json_slurp(Path input) {
    // classic is important, lazymap was causing problems
    def slurper = new groovy.json.JsonSlurperClassic()
    ArrayList result = slurper.parseText(input.text)
    return result.collectMany{ json_to_genome(it) }
}

def json_to_genome(HashMap slurped) {
    def meta    = [:]
    meta.id     = slurped.sample
    meta.is_vcf = slurped.vcf_path?: false
    meta.chrom  = slurped.chrom?: false

    def genome_lst = []

    if (meta.is_vcf) {
        vcf_path   = file(slurped.vcf_path, checkIfExists: true)
        genome_lst = [ meta, [ vcf_path ] ]
    } else {
        bed        = file(slurped.bed, checkIfExists: true)
        bim        = file(slurped.bim, checkIfExists: true)
        fam        = file(slurped.fam, checkIfExists: true)
        genome_lst = [ meta, [ bed, bim, fam ] ]
    }
    return genome_lst
}
