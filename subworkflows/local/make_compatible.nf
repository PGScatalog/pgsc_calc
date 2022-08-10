include { PLINK2_VCF         } from '../../modules/local/plink2_vcf'
include { PLINK2_RELABELBIM  } from '../../modules/local/plink2_relabelbim'
include { PLINK2_RELABELPVAR } from '../../modules/local/plink2_relabelpvar'
include { MATCH_VARIANTS     } from '../../modules/local/match_variants'

workflow MAKE_COMPATIBLE {
    take:
    geno
    pheno
    variants
    vcf
    scorefile
    db

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
        .set{ geno_std }

    PLINK2_RELABELBIM.out.pheno
        .mix(PLINK2_RELABELPVAR.out.pheno, PLINK2_VCF.out.psam)
        .dump(tag: 'make_compatible')
        .set{ pheno_std }

    PLINK2_RELABELBIM.out.variants
        .mix(PLINK2_RELABELPVAR.out.variants, PLINK2_VCF.out.pvar)
        .dump(tag: 'make_compatible')
        .set{ variants_std }

    // Recombine split variant information files to match target variants ------

    // custom groupKey() to set a different group size for each sample ID
    // different samples may have different numbers of chromosomes
    // see https://nextflow.io/docs/latest/operator.html#grouptuple
    // if a size is not provided then nextflow must wait for the entire process
    // to finish before releasing the grouped tuples, which can be very slow(!)

    variants_std.map { tuple(groupKey(it[0].subMap(['id', 'is_vcf', 'is_bfile', 'is_pfile']), it[0].n_chrom),
                     it[0].chrom, it[1]) }
        .groupTuple()
        .combine( scorefile )
        .dump(tag: 'match_variants_input')
        .set { ch_variants }

    // variants should be matched once per sample identifier
    MATCH_VARIANTS ( ch_variants )
    MATCH_VARIANTS.out.scorefile.dump(tag: 'match_variants_output')

    ch_versions = ch_versions.mix(MATCH_VARIANTS.out.versions)

    emit:
    geno       = geno_std
    pheno      = pheno_std
    variants   = variants_std
    scorefiles = MATCH_VARIANTS.out.scorefile
    db         = MATCH_VARIANTS.out.db
    versions   = ch_versions
}
