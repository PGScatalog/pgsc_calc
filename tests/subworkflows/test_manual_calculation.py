#!/usr/bin/env python

# make a synthetic plink bfile, then:
#   1) calculate a score with a manual matrix product
#   2) calculate scores with plink and compare with 1)
#   3) compare against workflow output and compare with 1)

import pytest
import pathlib
import numpy as np
import pandas as pd
import binascii
import os

@pytest.fixture
def bim():
    """ Make a PLINK1 variant information table with two alleles, a and b """
    d = {'chr': [1, 1], 'id': ['a', 'b'], 'cm': [0, 0], 'pos': [3, 4], \
         'ref': ['A', 'C'], 'alt': ['G', 'A'] }
    bim = pd.DataFrame(d)
    bim.to_csv('test.bim', index = False, header = None, sep = '\t')
    yield 'test.bim'
    os.remove('test.bim')

@pytest.fixture
def bim_df(bim):
    df = pd.read_csv(bim, sep = '\t', header = None)
    df.columns = ['chrom', 'id', 'cm', 'pos', 'ref', 'alt']
    return df

@pytest.fixture
def bed(bim_df):
    """ Make a PLINK1 biallelic genotype table (binary)
    V blocks of N/4 (rounded up) bytes
    V = n variants (2)
    N = n_samples (6)
    Sequence of 6 / 4 = 2 byte blocks (rounded up)
    One sequence per variant (4 byte blocks total)
    alice and bob are homozygous first allele for all variants
    dingus and doofus are heterozygous for all variants
    blarp and darp are homozygous second allele for all variants

    first block ------------------ second block -------------------
    10     | 10     | 00  | 00    | 00         | 00      | 11   | 11
    doofus | dingus | bob | alice | missing    | missing | darp | blarp
    10100000 | 00001111
    0xA0 0x0F
    """
    bim = bim_df
    magic_numbers = ['6c', '1b', '01']
    n_variants = bim.shape[0]
    genotypes = ['a0', '0f'] * n_variants
    genobytes = bytes.fromhex(''.join(magic_numbers + genotypes))

    with open('test.bed', 'w+b') as f:
        f.write(genobytes)

    yield 'test.bed'
    os.remove('test.bed')

@pytest.fixture
def fam():
    ''' Make a PLINK1 phenotype table for 6 samples '''

    f = {'FID': ['dummy']*6, 'IID': ['alice', 'bob', 'dingus', 'doofus', 'blarp', 'darp'],
         'F': [0]*6, 'M': [0]*6, 'sex': [0]*6, 'pheno': [0]*6 }
    pd.DataFrame(f).to_csv('test.fam', index = False, header = None, sep = '\t')
    yield 'test.fam'
    os.remove('test.fam')

@pytest.fixture
def bfiles(bed, bim, fam):
    ''' Return bfile prefix for plink '''
    return 'test'

@pytest.fixture
def simple_scorefile(bim_df):
    ''' A dumb scorefile with two alleles, both with effect weight 1 '''
    bim = bim_df
    scorefile = bim[['id', 'ref']].assign(effect_weight = [1.0, 1.0])
    scorefile.to_csv('test.scores', index = False, header = None, sep = '\t')
    yield 'test.scores'
    os.remove('test.scores')

@pytest.fixture
def manual_score(fam, simple_scorefile):
    ''' Calculate a score manually '''
    fam = pd.read_csv(fam, header = None, sep = '\t')
    score = pd.read_csv(simple_scorefile, header = None, sep = '\t')
    score.columns = ['id', 'ea', 'effect_weight']

    # homozygous effect allele: 2
    # heterozygous effect allele: 1
    # homozygous other allele: 0
    genotype = [2, 2, 1, 1, 0, 0]
    g = np.asarray([genotype, genotype]) # two variants with same genotypes
    scoresum = np.matmul(np.transpose(g), score['effect_weight'])

    # non-missing alleles = 4 (2 variants * 2 alleles for biallelic data)
    scores = pd.DataFrame({'manual_scoresum': scoresum }).assign(denom = 4)
    scores['manual_avg'] = scores['manual_scoresum'] / scores['denom']
    scores['IID'] = fam.iloc[:, 1]
    return scores

def test_plink(bfiles, simple_scorefile, manual_score):
    ''' Test that manual calculation matches plink calculation '''
    plink_cmd = "plink2 --bfile {} --score {} no-mean-imputation"
    os.system(plink_cmd.format(bfiles, simple_scorefile))
    assert os.path.exists('plink2.sscore')
    plink_scores = pd.read_csv('plink2.sscore', sep = '\t')
    assert all(plink_scores['NAMED_ALLELE_DOSAGE_SUM'] == manual_score['manual_scoresum'])
    assert all(plink_scores['SCORE1_AVG'] == manual_score['manual_avg'])

    [os.remove(x) for x in ['plink2.sscore', 'plink2.log']]

@pytest.mark.workflow('manual_calculation')
def test_pgsc_calc(workflow_dir, manual_score):
    ''' Compare pipeline output scores against manual calculation '''

    pgsc_calc_scores = pathlib.Path(workflow_dir, "output/score/aggregated_scores.txt")
    pgsc_calc_df = pd.read_csv(pgsc_calc_scores, sep = ' ')
    scores = pgsc_calc_df.merge(manual_score, on = 'IID', how = 'left')

    assert all (scores['manual_scoresum'] == scores['test_SUM'])
