#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_RELABELBIM } from '../../../../modules/local/plink2_relabelbim'
include { PLINK2_SCORE } from '../../../../modules/local/plink2_score.nf'

workflow testscore {
    // test a single score (one effect weight)
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
scorefile = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/test.scorefile')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )
}

workflow testsmallscore {
    // test a single score with a small dataset declared in metadata (n < 50)
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
    scorefile = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/test.scorefile')

    def meta = [id: 'test', is_bfile: true, n_samples: 1]
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )
}

workflow testmultiscore {
    // test a scoring file with multiple effect weights
    scorefile = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/multiscore.scorefile')
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}

workflow testsmallmultiscore {
    // test a scoring file with multiple effect weights and a small (n<50) sample size (set in metadata)
    scorefile = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/multiscore.scorefile')
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')

    def meta = [id: 'test', is_bfile: true, n_samples: 1]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}

workflow testmultiscorefail {
    // use a scoring file with one effect weight, but set multiple scores in scoremeta
    scorefile = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/test.scorefile')
    bim = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    bed = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bed')
    fam = file('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.fam')
    optional_allelic_freq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .mix(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}
