#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { PLINK2_RELABELBIM } from '../../../../modules/local/plink2_relabelbim'
include { PLINK2_SCORE } from '../../../../modules/local/plink2_score.nf'

workflow testscore {
    // test a single score (one effect weight)
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = file("assets/examples/scorefiles/test.scorefile", checkIfExists: true)    
    afreq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .concat(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile, afreq))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )
}

workflow testsmallscore {
    // test a single score with a small dataset declared in metadata (n < 50)
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = file("assets/examples/scorefiles/test.scorefile", checkIfExists: true)
    afreq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 1]
    def scoremeta = [n_scores: 1]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .concat(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile, afreq))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )
}

workflow testmultiscore {
    // test a scoring file with multiple effect weights
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = file("assets/examples/scorefiles/multiscore.txt", checkIfExists: true)
    afreq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .concat(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile, afreq))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}

workflow testsmallmultiscore {
    // test a scoring file with multiple effect weights and a small (n<50) sample size (set in metadata)
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = file("assets/examples/scorefiles/multiscore.txt", checkIfExists: true)
    afreq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 1]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .concat(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile, afreq))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}

workflow testmultiscorefail {
    // use a scoring file with one effect weight, but set multiple scores in scoremeta
    bim = file("assets/examples/target_genomes/cineca_synthetic_subset.bim", checkIfExists: true)
    bed = file("assets/examples/target_genomes/cineca_synthetic_subset.bed", checkIfExists: true)
    fam = file("assets/examples/target_genomes/cineca_synthetic_subset.fam", checkIfExists: true)
    scorefile = file("assets/examples/scorefiles/test.scorefile", checkIfExists: true)
    optional_allelic_freq = file('NO_FILE')

    def meta = [id: 'test', is_bfile: true, n_samples: 100]
    def scoremeta = [n_scores: 2]

    PLINK2_RELABELBIM( Channel.of([meta, bed, bim, fam]) )

    PLINK2_RELABELBIM.out.geno
        .concat(PLINK2_RELABELBIM.out.pheno, PLINK2_RELABELBIM.out.variants)
        .groupTuple(size: 3)
        .map{ it.flatten() }
        .concat(Channel.of(scoremeta, scorefile))
        .collect()
        .set { genomes }

    PLINK2_SCORE( genomes )

}
