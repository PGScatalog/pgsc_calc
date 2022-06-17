import pandas as pd
import polars as pl
import pytest
import requests as req
import os
import sqlite3
import sys
sys.path.append("..")
from bin.match_variants import *
pl.Config.set_global_string_cache()

@pytest.fixture
def score():
    ''' Scorefile dataframe with no effect type '''
    d = {'chr_name': ['22'], 'chr_position': [17080378], 'effect_allele': 'A', 'other_allele': 'G', 'effect_weight': 1.01, 'effect_type': 'additive', 'accession': 'dummy'}
    pd.DataFrame(d).to_csv('score.txt', sep = '\t', index = False)
    yield 'score.txt'
    os.remove('score.txt')

@pytest.fixture
def score_df(score):
    d = read_scorefile(score)
    assert d.columns == ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type', 'accession']
    types = [pl.Utf8, pl.Int64, pl.Categorical, pl.Categorical, pl.Float64, pl.Categorical, pl.Categorical]
    assert d.dtypes == types
    return d

@pytest.fixture
def score_df_noOA(score_df):
    return score_df.with_column(pl.lit(None).alias('other_allele'))

@pytest.fixture
def bad_score(score_df):
    ''' Scorefile dataframe with no matches in test target '''
    bad_score = score_df.clone()
    bad_score.replace('chr_name', pl.Series("chr_name", ['21']))
    return bad_score

@pytest.fixture
def duplicate_id_diff_ea(score_df):
    ''' Scorefile dataframe with duplicate ID and different effect allele  '''
    df = pl.concat([score_df, score_df])
    df.replace('effect_allele', pl.Series('effect_allele', ['A', 'G']))
    return df

@pytest.fixture
def score_dict(accession, accession_two, score):
    return { accession: score, accession_two: score }

@pytest.fixture
def target():
    ''' Target genome bim path '''
    try:
        bim = req.get('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset.bim', timeout = 5)
    except (req.exceptions.ConnectionError, req.Timeout):
        bim = []

    if not bim:
        pytest.skip("Couldn't get test data from network")
    else:
        with open('data.bim', 'wb') as f:
            f.write(bim.content)

        yield 'data.bim'
        os.remove('data.bim')

@pytest.fixture
def target_multiallelic(target):
    """ Make multiallelic target variant data """
    x = pl.read_csv(target, sep='\t', has_header = False)
    x.columns = ['#CHROM', 'ID', 'CM', 'POS', 'REF', 'ALT']
    x.with_column(pl.concat_str([pl.col('ALT'), pl.lit(',G')]).alias("ALT")).write_csv('multiallelic.txt', sep = '\t')
    yield 'multiallelic.txt'
    os.remove('multiallelic.txt')

@pytest.fixture
def target_df(target):
    ''' Target genome dataframe '''
    return read_target(target, 'bim', remove_multiallelic = False, n_threads = 1)

@pytest.fixture
def matches(score_df, target_df):
    return get_all_matches(target_df, score_df, remove_ambig = False)

@pytest.fixture
def match_dup(matches):
    m2 = matches.clone()
    m2.replace('effect_allele', pl.Series('effect_allele', ['G']))
    return pl.concat([matches, m2])

def test_split_effect(score_df):
    ''' Test that scorefiles are split by effect type '''
    split = split_effect_type(score_df)
    assert 'additive' in split
    assert split['additive'].shape[0] == score_df.shape[0]

def test_match(score_df, target_df):
    ''' Test unambiguous matching works OK '''
    m = get_all_matches(target = target_df, scorefile = score_df, remove_ambig = True)
    assert m.shape == (1, 14)
    assert not all(m['ambiguous'])

def test_bad_match(bad_score, target_df):
   ''' Ensure no matches are returned with a bad scorefile '''
   m = get_all_matches(target = target_df, scorefile = bad_score, remove_ambig = True)
   assert m.shape == (0, 14)

def test_unduplicate(matches, match_dup):
    ''' Test that duplicate IDs + diff effect allele are split appropriately '''

    # only tests ID with 2 different effect alleles (not multiallelic)

    # test with positive case --------------------------------------------------
    d2 = unduplicate_variants(match_dup)

    assert isinstance(d2, list)

    # no variants should go missing
    n_vars = 0
    for df in d2:
        n_vars += df.shape[0]
    assert n_vars == match_dup.shape[0]

    # make sure splitting happened
    assert d2[0].shape[0] == 1
    assert d2[-1].shape[0] == 1

    # make sure alleles are consistent after splitting
    assert d2[0]['effect_allele'] == pl.Series('effect_allele', ['G'])
    assert d2[-1]['effect_allele'] == matches['effect_allele']

    # test with negative case --------------------------------------------------
    d = unduplicate_variants(matches)

    assert isinstance(d, list)

    n_vars = 0
    for df in d:
        n_vars += df.shape[0]

    assert n_vars == matches.shape[0]

    assert d[0].shape[0] == matches.shape[0]

    assert d[0]['effect_allele'] == matches['effect_allele']

def test_multiallelic(target_multiallelic):
    raw_shape = pl.read_csv(target_multiallelic, sep = '\t', header = False).shape
    ma = read_target(target_multiallelic, 'pvar', remove_multiallelic = False, n_threads = 1)
    no_ma = read_target(target_multiallelic, 'pvar', remove_multiallelic = True, n_threads = 1)

    # every variant is multiallelic, so they should be all removed
    assert no_ma.shape[0] == 0

    # each variant has two alternate alleles, check if exploding worked OK
    assert ma.shape[0] == raw_shape[0] * 2

def test_format_scorefile(matches):
    # manually format a score
    formatted_score = matches[['ID', 'effect_allele', 'effect_weight']]
    formatted_score.columns = ['ID', 'effect_allele', 'dummy'] # dummy = accession

    split_score = format_scorefile(matches, split = True)

    # check dict key = chrom
    assert list(split_score.keys()) == ['22']
    assert split_score['22'].frame_equal(formatted_score)

    unsplit_score = format_scorefile(matches, split = False)

    # check dict key = false when not split
    assert list(unsplit_score.keys()) == ['false']

    assert unsplit_score['false'].frame_equal(formatted_score)

def test_write_scorefile(matches):
    # manually format a score
    formatted_score = matches[['ID', 'effect_allele', 'effect_weight']]
    formatted_score.columns = ['ID', 'effect_allele', 'dummy'] # dummy = accession

    ets: Dict[str, pl.DataFrame] = split_effect_type(matches)
    unduplicated: Dict[str, pl.DataFrame] = {k: unduplicate_variants(v) for k, v in ets.items()}
    ea_dict: Dict[str, str] = {'is_dominant': 'dominant', 'is_recessive': 'recessive', 'additive': 'additive'}

    split = False
    [write_scorefile(ea_dict.get(k), v, split) for k, v in unduplicated.items()]

    # check the written score is equal to a subset of the input dataframe
    assert pl.read_csv('false_additive_0.scorefile', sep = '\t').frame_equal(formatted_score)

    os.remove('false_additive_0.scorefile')


def test_connectdb():
    assert type(connect_db('test.db')) == type(sqlite3.connect(':memory:'))


def test_check_match():
    # only half of the variants match here
    df = pl.DataFrame({'accession': ['dummy','dummy'], 'match_type': ['refalt', None]})

    # fail with 95% minimum match rate
    with pytest.raises(AssertionError):
        check_match(df, 0.95)

    # pass with 10% minimum match rate
    assert check_match(df, 0.1) is None

def test_args():
    with pytest.raises(SystemExit):
        # mandatory args: -dataset, -target, -scorefile, -min_overlap
        parse_args(['-d', 'dummy', '-t', 'hi'])

    args = parse_args(['-d', 'dataset', '-t', 'target', '-s', 'scorefile', '-m',
                       '0.95', '--format', 'bim', '--db', 'test.db'])

    # check default parameters for optional arguments
    assert args.remove_multiallelic
    assert args.remove_ambiguous
    assert not args.split

def test_match_no_oa(score_df_noOA, target_df):
    """ Test matching a scorefile without other allele information """
    x = get_all_matches(target_df, score_df_noOA, remove_ambig = False)

    # all other alleles remain null after matching
    assert all(x['other_allele'].is_null())

    # a match has occurred (effect allele == ref)
    assert x.shape[0] == score_df_noOA.shape[0]
