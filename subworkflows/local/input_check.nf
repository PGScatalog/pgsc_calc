//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_JSON } from '../../modules/local/samplesheet_json'
include { SCOREFILE_CHECK  } from '../../modules/local/scorefile_check'

workflow INPUT_CHECK {
    take:
    input // file: /path/to/samplesheet.csv
    format // csv or JSON
    scorefile // flat list of paths

    main:
    ch_versions = Channel.empty()

    if (format.equals("csv")) {
        SAMPLESHEET_JSON(input)
        ch_versions = ch_versions.mix(SAMPLESHEET_JSON.out.versions)
        SAMPLESHEET_JSON.out.json
            .map { json_slurp(it) }
            .flatMap { count_chrom(it) }
            .buffer ( size: 2 )
            .branch {
                vcf: it[0].is_vcf
                bfile: !it[0].is_vcf
            }
            .set { ch_input }
    } else if (format.equals("json")) {
        Channel.from(input)
            .map { json_slurp(it) }
            .flatMap { count_chrom(it) }
            .buffer( size: 2 )
            .branch {
                vcf: it[0].is_vcf
                bfile: !it[0].is_vcf
            }
            .set { ch_input }
    }

    // branch is like a switch statement, so only one bed / bim was being
    // returned
    ch_input.bfile.multiMap { it ->
        bed: [it[0], it[1][0]]
        bim: [it[0], it[1][1]]
        fam: [it[0], it[1][2]]
    }
        .set { ch_bfiles }

    // check scorefiles
    SCOREFILE_CHECK ( scorefile )
    ch_versions = ch_versions.mix(SCOREFILE_CHECK.out.versions)

    emit:
    bed = ch_bfiles.bed
    bim = ch_bfiles.bim
    fam = ch_bfiles.fam
    vcf = ch_input.vcf
    scorefiles = SCOREFILE_CHECK.out.scorefiles
    versions = ch_versions
}

def json_slurp(Path input) {
    // classic is important, lazymap was causing problems
    def slurper = new groovy.json.JsonSlurperClassic()
    ArrayList result = slurper.parseText(input.text)
    return result.collectMany{ json_to_genome(it) }
}

def json_to_genome(HashMap slurped) {
    // parse slurped JSON into [[meta], [path_to_target_genome]]
    def meta    = [:]
    meta.id     = slurped.sample
    meta.is_vcf = slurped.vcf_path ? true : false
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

def count_chrom(ArrayList genomes) {
    // count the number of chromosomes associated with each sample ID
    // add this value to the meta map
    maps = genomes.findAll { it instanceof HashMap }
    n_chrom = maps.groupBy { it.id }
        .collectEntries { key, map -> [key, map*.chrom.size()] }
    return genomes.each {
        if ( it instanceof HashMap ) {
            it.n_chrom = n_chrom[it.id]
        }
    }
}
