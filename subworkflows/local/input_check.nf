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
    reference

    main:
    /* all genomic data should be represented as a list of : [[meta], file]

       meta hashmap structure:
        id: experiment label, possibly shared across split genomic files
        is_vcf: boolean, is in variant call format
        is_bfile: boolean, is in PLINK1 fileset format
        is_pfile: boolean, is in PLINK2 fileset format
        chrom: The chromosome associated with the file. If multiple chroms, null.
        n_chrom: Total separate chromosome files per experiment ID
     */

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
                bfile: it[0].is_bfile
                pfile: it[0].is_pfile
            }
            .set { ch_input }
    } else if (format.equals("json")) {
        input
            .map { json_slurp(it) }
            .flatMap { count_chrom(it) }
            .buffer( size: 2 )
            .branch {
                vcf: it[0].is_vcf
                bfile: it[0].is_bfile
                pfile: it[0].is_pfile
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

    ch_input.pfile.multiMap { it ->
        pgen: [it[0], it[1][0]]
        psam: [it[0], it[1][1]]
        pvar: [it[0], it[1][2]]
    }
        .set { ch_pfiles }

    SCOREFILE_CHECK ( scorefile, reference )

    versions = ch_versions.mix(SCOREFILE_CHECK.out.versions)

    ch_bfiles.bed.mix(ch_pfiles.pgen).dump(tag: 'input').set { geno }
    ch_bfiles.bim.mix(ch_pfiles.pvar).dump(tag: 'input').set { variants }
    ch_bfiles.fam.mix(ch_pfiles.psam).dump(tag: 'input').set { pheno }
    ch_input.vcf.dump(tag: 'input').set{vcf}
    SCOREFILE_CHECK.out.scorefiles.dump(tag: 'input').set{ scorefiles }

    emit:
    geno
    variants
    pheno
    vcf
    scorefiles
    db         = SCOREFILE_CHECK.out.log
    versions
}

def json_slurp(Path input) {
    // classic is important, lazymap was causing problems
    def slurper = new groovy.json.JsonSlurperClassic()
    ArrayList result = slurper.parseText(input.text)
    return result.collectMany{ json_to_genome(it) }
}

def json_to_genome(HashMap slurped) {
    // parse slurped JSON into [[meta], [path_to_target_genome]]
    def meta      = [:]

    meta.id       = slurped.sample
    meta.is_vcf   = slurped.vcf_path ? true : false
    meta.is_bfile = slurped.bed ? true : false
    meta.is_pfile = slurped.pgen ? true : false
    meta.chrom    = slurped.chrom? slurped.chrom.toInteger() : false

    def genome_lst = []

    if (meta.is_vcf) {
        vcf_path   = file(slurped.vcf_path, checkIfExists: true)
        genome_lst = [ meta, [ vcf_path ] ]
    } else if (meta.is_bfile) {
        bed        = file(slurped.bed, checkIfExists: true)
        bim        = file(slurped.bim, checkIfExists: true)
        fam        = file(slurped.fam, checkIfExists: true)
        genome_lst = [ meta, [ bed, bim, fam ] ]
    } else if (meta.is_pfile) {
        pgen       = file(slurped.pgen, checkIfExists: true)
        psam       = file(slurped.psam, checkIfExists: true)
        pvar       = file(slurped.pvar, checkIfExists: true)
        genome_lst = [ meta, [ pgen, psam, pvar ] ]

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
