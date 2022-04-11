import pytest
import numpy as np
import pandas as pd
import requests as req
import gzip
from pyliftover import LiftOver

import sys
sys.path.append("..")
from bin.read_scorefile import *

@pytest.fixture
def db():
    ''' Download reference database from gitlab '''
    database = req.get('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/reference_data/pgsc_calc_ref.sqlar')
    with open('db.sqlar', 'wb') as f:
        f.write(database.content)
    yield 'db.sqlar'
    os.remove('db.sqlar')

@pytest.fixture
def chain_files(db):
    ''' Stage chain files from reference database in working directory '''
    os.system('sqlite3 db.sqlar -Ax hg19ToHg38.over.chain.gz hg38ToHg19.over.chain.gz')
    yield ['hg19ToHg38.over.chain.gz', 'hg38ToHg19.over.chain.gz']
    os.remove('hg38ToHg19.over.chain.gz')
    os.remove('hg19ToHg38.over.chain.gz')

@pytest.fixture
def valid_chrom():
    ''' Autosomes (1 - 22) are valid, which will cause problems for non-human species '''
    return 1

@pytest.fixture
def invalid_chrom():
    ''' Only integer chromosomes are supported '''
    return "random string"

@pytest.fixture
def annotated_chrom():
    ''' LiftOver sometimes returns annotated chromosomes '''
    return "22_annotations_that_are_annoying"

@pytest.fixture
def accession():
    ''' A placeholder PGS Catalog accession '''
    return "PGS000802"

@pytest.fixture
def hg38_coords():
    ''' A dataframe of random variants, pos in GRCh38 '''
    d = {'rsid' : ['rs11903757', 'rs6061231'], 'chr_name': [2, 20], 'chr_position': [191722478, 62381861] }
    return pd.DataFrame(d)

@pytest.fixture
def hg38_to_hg19_coords(hg38_coords):
    ''' A dataframe containing known good coordinates in GRCh37, from dbSNP '''
    d = {'lifted_chr': [2, 20], 'lifted_pos': [192587204, 60956917], 'liftover': [True, True] }
    return (hg38_coords.join(pd.DataFrame(d, dtype = 'Int64'), how = 'outer')
            .astype({'liftover': bool}))

@pytest.fixture
def hg19_unique_coords():
    ''' A dataframe of coordinates that are deleted in hg38 and won't map '''
    d = {'chr_name': [22, 22, 22], 'chr_position': [22561610, 23412058, 28016883]}
    return pd.DataFrame(d)

@pytest.fixture
def hg38():
    ''' The only input the workflow should accept, but equivalent to hg38 '''
    return 'GRCh38'

@pytest.fixture
def hg19():
    ''' The only input the workflow should accept, but equivalent to hg19 '''
    return 'GRCh37'

@pytest.fixture
def lo_tohg19():
    ''' pyliftover object reponsible for converting coordinates hg38 -> hg19 '''
    return LiftOver('hg38', 'hg19')

@pytest.fixture
def lo_tohg38():
    ''' pyliftover object reponsible for converting coordinates hg19 -> hg38 '''
    return LiftOver('hg19', 'hg38')

@pytest.fixture
def min_lift():
    ''' Minimum proportion of variants to successfully remap coordinates '''
    return 0.95

@pytest.fixture
def scoring_file_noheader():
    ''' Fetch a scorefile without genome build data in the metadata header '''
    scorefile = req.get('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000802/ScoringFiles/PGS000802.txt.gz')
    with open('PGS000802.txt', 'wb') as f:
        f.write(gzip.decompress(scorefile.content))
    yield 'PGS000802.txt'
    os.remove('PGS000802.txt')

@pytest.fixture
def scoring_file_header():
    ''' Fetch a scorefile with genome build data in the metadata header '''
    scorefile = req.get('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000777/ScoringFiles/PGS000777.txt.gz')
    with open('PGS000777.txt', 'wb') as f:
        f.write(gzip.decompress(scorefile.content))
    yield 'PGS000777.txt'
    os.remove('PGS000777.txt')

@pytest.fixture
def scoring_file_noOA(scoring_file_noheader):
    ''' A scoring file (path) with no other allele '''
    f = pd.read_table(scoring_file_noheader, comment = '#')
    f.drop(['other_allele'], inplace = True, axis = 1)
    f.to_csv('no_oa.txt', sep = '\t', index = False)
    yield 'no_oa.txt'
    os.remove('no_oa.txt')

@pytest.fixture
def scoring_file_noEA(scoring_file_noheader):
    ''' A scoring file (path) with no other allele '''
    f = pd.read_table(scoring_file_noheader, comment = '#')
    f.drop(['effect_allele'], inplace = True, axis = 1)
    f.to_csv('no_ea.txt', sep = '\t', index = False)
    yield 'no_ea.txt'
    os.remove('no_ea.txt')

@pytest.fixture
def out_scorefile():
    yield 'out.txt'
    os.remove('out.txt')

@pytest.fixture
def multi_et_scorefile_df(scoring_file_noheader):
    ''' Scorefile dataframe with multiple effect types '''
    return pd.read_table(scoring_file_noheader, comment = '#')

@pytest.fixture
def bad_multi_et_scorefile_df(multi_et_scorefile_df):
    ''' Scorefile dataframe with bad (mixed) effect types '''
    return multi_et_scorefile_df.assign(is_dominant = True)

@pytest.fixture
def good_score_df():
    ''' Scorefile dataframe with no effect type '''
    d = {'chr_name': [22], 'chr_position': [22561610], 'effect_allele': 'A', 'other_allele': 'G', 'effect_weight': 1}
    return pd.DataFrame(d)

@pytest.fixture
def duplicate_score_df(good_score_df):
    ''' Bad scorefile dataframe with duplicate variants '''
    return pd.concat([good_score_df, good_score_df])

@pytest.fixture
def multi_score_df(good_score_df):
    ''' A scorefile dataframe with multiple effect weight columns '''
    return (good_score_df
            .rename( columns = { 'effect_weight': 'effect_weight_one' } )
            .assign( effect_weight_two = 1 ))

@pytest.fixture
def df_cols():
    ''' Expected column names of a parsed scorefile '''
    return { 'chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type' }

def test_valid_chrom(valid_chrom):
    assert to_int(valid_chrom) == 1
    assert parse_lifted_chrom(valid_chrom) == 1

def test_invalid_chrom(invalid_chrom):
    assert to_int(invalid_chrom) is None
    assert parse_lifted_chrom(invalid_chrom) is None

def test_annotated_chrom(annotated_chrom):
    assert parse_lifted_chrom(annotated_chrom) == 22

def test_remap(hg38_coords, lo_tohg19, lo_tohg38, hg38_to_hg19_coords, hg19_unique_coords):
    ''' Test known genomic coordinates are valid when remapped '''
    # test valid positions are mapped from (GRCh38 -> GRCh37)
    hg38_coords[['lifted_chr', 'lifted_pos']] = hg38_coords.apply(lambda x: convert_coordinates(x, lo_tohg19), axis = 1)
    assert hg38_coords.equals(hg38_to_hg19_coords.drop('liftover', axis = 1))

    # test invalid positions that won't map (GRCh37 -> GRCh38)
    assert (hg19_unique_coords
        .apply(lambda x: convert_coordinates(x, lo_tohg38), axis = 1)
        .isnull()
        .all(axis=None)
            )

def test_liftover(accession, hg38_coords, hg38_to_hg19_coords, hg19, hg38, min_lift, hg19_unique_coords, chain_files):
    """ Test liftover function, which is applied to each scoring file

    chain_files fixture used only for staging reference data in working directory
    normally the nextflow module takes care of this
    """

    lifted, _ = liftover(accession, hg38_coords, hg38, hg19, min_lift)
    assert lifted.equals(hg38_to_hg19_coords)

    lift_same_build, _ = liftover(accession, hg38_coords, hg38, hg38, min_lift)
    # drop liftover status label, it's not important for this test
    assert lift_same_build.drop('liftover', axis = 1).equals(hg38_coords)

    # test min_overlap throws an error
    with pytest.raises(AssertionError):
        liftover(accession, hg19_unique_coords, hg19, hg38, min_lift)

def test_read_build(accession, scoring_file_noheader, scoring_file_header):
    ''' Test reading genome build from scoring file header metadata '''

    assert read_build(scoring_file_noheader) is None
    assert read_build(scoring_file_header) == 'hg19'

    # now check the error checking
    # lifting over without a build number should raise assertion error
    with pytest.raises(AssertionError):
        check_build(accession, read_build(scoring_file_noheader))
    assert check_build(accession, read_build(scoring_file_header)) is None

def test_read_scorefile(scoring_file_header, scoring_file_noheader, df_cols):
    ''' Test reading a scorefile to a consistent dataframe layout '''
    assert get_accession(scoring_file_header) == 'PGS000777'

    # rsid without position information raises an error
    with pytest.raises(AssertionError):
        read_scorefile(scoring_file_header)

    df_dict, _ = read_scorefile(scoring_file_noheader)
    assert 'PGS000802' in df_dict
    # https://www.pgscatalog.org/score/PGS000802/
    # 19 variants, 6 columns
    assert df_dict['PGS000802'].shape == (19, 6)
    assert set(df_dict['PGS000802'].columns) == df_cols

def test_qc(accession, good_score_df, duplicate_score_df):
    ''' Test simple quality control checks on a scorefile dataframe '''
    with pytest.raises(AssertionError):
        quality_control(accession, duplicate_score_df)

    assert quality_control(accession, good_score_df).shape == (1, 5)

def test_set_effect_type(accession, good_score_df, multi_et_scorefile_df, bad_multi_et_scorefile_df ):
    ''' Check setting effect types for additive, recessive, and dominant '''

    path = 'placeholder/path/' # only used to generate an error message

    # the effect_column should contain the default effect type
    df = set_effect_type(good_score_df, path)
    assert df.effect_type.unique() == 'additive'

    # the effect_type column should contain three possible types
    df_multi_et = set_effect_type(multi_et_scorefile_df, path)
    expected_ets = {'is_dominant', 'is_recessive', 'additive'}
    assert set(df_multi_et.effect_type.unique()) == expected_ets

    with pytest.raises(AssertionError):
        # variants can never be dominant and recessive simultaneously
        set_effect_type(bad_multi_et_scorefile_df, path)

def test_multi_effect_weights(multi_score_df, df_cols):
    ''' Check multiple effect weights are properly split into a dict of df '''
    d = multi_ew(multi_score_df)
    # check effect weights 'one' and 'two' are dict keys
    assert set(d.keys()) == {'one', 'two'}

    # ... and dict values are dfs with proper columns
    assert set(d['one'].columns) == df_cols
    assert set(d['two'].columns) == df_cols

def test_missing_alleles(scoring_file_noOA, scoring_file_noEA):
    """ Test that reading a scorefile without effect alleles or other alleles
    specified raises an assertion error """

    with pytest.raises(AssertionError) as excinfo:
        read_scorefile(scoring_file_noOA)

    assert "Missing" in str(excinfo.value)

    with pytest.raises(AssertionError) as excinfo_ea:
        read_scorefile(scoring_file_noEA)

    assert "Missing" in str(excinfo_ea.value)
