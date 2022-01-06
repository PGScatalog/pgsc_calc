include { PLINK_VCF } from '../../modules/nf-core/modules/plink/vcf/main'

workflow JSON_CHECK {
    take:
    json

    main:
    ch_versions = Channel.empty()

    json
        .map{json_variant_channel(it)}
        .set{ ch_input }

    // TODO: validate the JSON like sample sheet checking?
    PLINK_VCF (
        ch_input
    )
    ch_versions = ch_versions.mix(PLINK_VCF.out.versions.first())

    emit:
    bed = PLINK_VCF.out.bed
    bim = PLINK_VCF.out.bim
    fam = PLINK_VCF.out.fam
    versions = ch_versions
}

// JSON input was parsed into an object by groovy :)
// just make it [[meta], vcf]
def json_variant_channel(LinkedHashMap x) {
    def meta = [:]
    meta.id = x.id
    meta.is_vcf = true
    meta.chrom = x.chrom?: false

    array = [meta, file(x.vcf_path, checkIfExists: true)]
    return array
}
