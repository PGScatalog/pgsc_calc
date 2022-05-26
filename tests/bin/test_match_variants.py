import pandas as pd
import polars as pl
import pytest
import requests as req
import os

import sys
sys.path.append("..")
from bin.match_variants import *
pl.Config.set_global_string_cache()

@pytest.fixture
def score():
    ''' Scorefile dataframe with no effect type '''
    d = {'chr_name': [22], 'chr_position': [17080378], 'effect_allele': 'A', 'other_allele': 'G', 'effect_weight': 1.01, 'effect_type': 'additive', 'accession': 'dummy'}
    pd.DataFrame(d).to_csv('score.txt', sep = '\t', index = False)
    yield 'score.txt'
    os.remove('score.txt')

@pytest.fixture
def score_df(score):
    d = read_scorefile(score)
    assert d.columns == ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type', 'accession']
    types = [pl.Int64, pl.Int64, pl.Categorical, pl.Categorical, pl.Float64, pl.Categorical, pl.Categorical]
    assert d.dtypes == types
    return d

@pytest.fixture
def bad_score(score_df):
    ''' Scorefile dataframe with no matches in test target '''
    bad_score = score_df.clone()
    bad_score.replace('chr_name', pl.Series("chr_name", [21]))
    return bad_score

@pytest.fixture
def score_dict(accession, accession_two, score):
    return { accession: score, accession_two: score }

@pytest.fixture
def target():
    ''' Target genome bim path '''
    bim = req.get('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim')
    with open('data.bim', 'wb') as f:
        f.write(bim.content)
    yield 'data.bim'
    os.remove('data.bim')

@pytest.fixture
def target_df(target):
    ''' Target genome dataframe '''
    return read_target(target, 'bim')

@pytest.fixture
def target_df_dup(target_df):
    ''' Target genome dataframe with duplicate ID '''
    return pl.concat([target_df, target_df])

def test_unduplicate_variants(target_df, target_df_dup):
    ''' Test that duplicate IDs (diff effect allele) are split appropriately '''
    d = unduplicate_variants(target_df)
    assert isinstance(d, dict)
    assert d['first'].shape[0] == target_df.shape[0]
    assert d['dup'].shape[0] == 0

    f = unduplicate_variants(target_df_dup)
    assert f['first'].shape == target_df.shape
    assert f['dup'].shape == target_df.shape

def test_split_effect(score_df):
    ''' Test that scorefiles are split by effect type '''
    split = split_effect_type(score_df)
    assert 'additive' in split
    assert split['additive'].shape[0] == score_df.shape[0]

def test_match(score_df, target_df):
    ''' Test unambiguous matching works OK '''
    m = get_all_matches(target = target_df, scorefile = score_df, remove = True)
    assert m.shape == (1, 14)
    assert not all(m['ambiguous'])

def test_bad_match(bad_score, target_df):
   ''' Ensure no matches are returned with a bad scorefile '''
   m = get_all_matches(target = target_df, scorefile = bad_score, remove = True)
   assert m.shape == (0, 14)
