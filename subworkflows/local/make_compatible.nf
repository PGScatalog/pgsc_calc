include { PLINK2_VCF         } from '../../modules/local/plink2_vcf'
include { PLINK2_RELABELBIM  } from '../../modules/local/plink2_relabelbim'
include { PLINK2_RELABELPVAR } from '../../modules/local/plink2_relabelpvar'

workflow MAKE_COMPATIBLE {
    take:
    geno
    pheno
    variants
    vcf

    main:
    ch_versions = Channel.empty()

    // Relabel input variant information to a common standard ------------------
    geno
        .mix(pheno, variants)
        .groupTuple(size: 3, sort: true)
        .map { it.flatten() }
        .set { fileset }

    PLINK2_RELABELBIM( fileset )
    ch_versions = ch_versions.mix(PLINK2_RELABELBIM.out.versions.first())

    PLINK2_RELABELPVAR( fileset )
    ch_versions = ch_versions.mix(PLINK2_RELABELPVAR.out.versions.first())

    // Recode VCF files to common standard -------------------------------------
    PLINK2_VCF(vcf)
    ch_versions = ch_versions.mix(PLINK2_VCF.out.versions.first())

    // Combine standardised data into genotype, phenotype, and variant channels
    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELPVAR.out.geno, PLINK2_VCF.out.pgen)
        .dump(tag: 'make_compatible')
        .set{ geno_all }

    PLINK2_RELABELBIM.out.pheno
        .mix(PLINK2_RELABELPVAR.out.pheno, PLINK2_VCF.out.psam)
        .dump(tag: 'make_compatible')
        .set{ pheno_all }

    PLINK2_RELABELBIM.out.variants
        .mix(PLINK2_RELABELPVAR.out.variants, PLINK2_VCF.out.pvar)
        .set{ variants_all }

    PLINK2_RELABELBIM.out.vmiss
        .mix(PLINK2_RELABELPVAR.out.vmiss, PLINK2_VCF.out.vmiss)
        .dump(tag: 'make_compatible')
        .set { vmiss }

    emit:
    geno       = geno_all
    pheno      = pheno_all
    variants   = variants_all
    vmiss      = vmiss
    versions   = ch_versions
}
