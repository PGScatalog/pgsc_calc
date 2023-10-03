//
// Create a database containing reference data required for ancestry inference
//
include { SETUP_RESOURCE } from '../../../modules/local/ancestry/bootstrap/setup_resource'
include { PLINK2_RELABELPVAR as BOOTSTRAP_RELABEL } from '../../../modules/local/plink2_relabelpvar'
include { MAKE_DATABASE } from '../../../modules/local/ancestry/bootstrap/make_database'

workflow BOOTSTRAP_ANCESTRY {
    take:
    reference_samplesheet

    main:
    ch_versions = Channel.empty()

    reference_samplesheet
        .splitCsv(header: true).map { create_ref_input_channel(it) }
        .branch {
            king: !it.first().is_pfile
            plink2: it.first().is_pfile
        }
        .set{ ref }

    ref.plink2
    // closure guarantees sort order: -> pgen, psam, pvar
    // important for processes to refer to file types correctly
        .groupTuple(size: 3, sort: { it.toString().split(".p")[-1] } )
        .map { it.flatten() }
        .dump( tag: 'ref_raw' )
        .set { ch_plink }

    SETUP_RESOURCE( ch_plink )
    ch_versions = ch_versions.mix(SETUP_RESOURCE.out.versions)

    SETUP_RESOURCE.out.plink.dump( tag: 'ref_setup' )

    BOOTSTRAP_RELABEL( SETUP_RESOURCE.out.plink )
    ch_versions = ch_versions.mix(BOOTSTRAP_RELABEL.out.versions.first())

    BOOTSTRAP_RELABEL.out.geno
        .concat(BOOTSTRAP_RELABEL.out.pheno, BOOTSTRAP_RELABEL.out.variants)
        .dump(tag: 'ancestry_relabelled')
        .set { relabelled }

    relabelled.map { check_relabelled_size(it) }

    relabelled
        .groupTuple(size: 3)
        .dump(tag: 'ancestry_relabelled_grouped')
        .map { drop_meta_keys(it).flatten() }
        .set{ relabelled_flat }     

    ref.king.branch {
        GRCh37: it[0].build == "GRCh37"
        GRCh38: it[0].build == "GRCh38"
    }.set { ch_king }

    relabelled_flat
        .flatten()
        .filter(Path)
        .collect()
        .dump(tag: 'ancestry_ref')
        .set { ch_raw_ref }

    Channel.fromPath(params.ancestry_checksums, checkIfExists: true)
        .set { ch_checksums }

    MAKE_DATABASE( ch_raw_ref, ch_king.GRCh37, ch_king.GRCh38, ch_checksums )
    ch_versions = ch_versions.mix(MAKE_DATABASE.out.versions)

    emit:
    reference_database = MAKE_DATABASE.out.reference
    versions = ch_versions
}


def drop_meta_keys(ArrayList it) {
    // input: [[meta hashmap], [file1, file2, file3]]
    // cloning is important when modifying the hashmap
    m = it.first().clone()
    // dropping keys simplifies joining with build specific reference data
    m.remove('type')
    m.remove('is_pfile')
    return [m, it.last()]
}


def create_ref_input_channel(LinkedHashMap row) {
    def meta = [:]
    meta.id = row.reference
    meta.build = row.build
    meta.chrom = "ALL"

    if (row.type == 'king') {
        meta.is_pfile = false
    } else {
        meta.is_pfile = true
    }

    return [meta, file(row.url, checkIfExists: true)]
}

def check_relabelled_size(ArrayList it) {
    // short explanation:
    // check that the PLINK2_RELABEL process hasn't accidentally picked up more
    // than one geno, pheno, and variant file. this shouldn't ever happen.
    assert it.size() == 2, "Multiple files detected in RELABEL_PVAR output. Check the storeDir!"

    // long explanation:
    // the output file names are dynamic, and use variables defined in the
    // script block that can't be captured in the output block
    // so the process uses a wildcard in output paths (e.g. "*.pvar.zst")

    // this is OK in a normal isolated working directory
    // however, when using a storeDir, the output files may no longer be isolated
    // this can cause confusing problems when making the reference database

    // by default storeDirs are set up to have one plink file triplet per folder,
    // but if this doesn't happen an explicit error here is helpful

    // GOOD OUTPUT             | BAD OUTPUT
    // [[meta], data.pvar.zst] | [[meta]. data.pvar.zst, all_phase3.pvar.zst, ...]
    // [[meta], data.pgen]     | [[meta]. data.pgen.zst, all_phase3.pgen, ...]
    // [[meta], data.psam]     | [[meta]. data.pgen.zst, all_phase3.psam, ...]
}
