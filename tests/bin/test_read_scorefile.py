import pytest
import numpy as np
import pandas as pd
import requests as req
import gzip
from pyliftover import LiftOver

import sys
sys.path.append("..")
from bin.read_scorefile import *

def get_timeout(url):
    """ Get a remote file with timeout """
    try:
        return req.get(url, timeout = 5)
    except (req.exceptions.ConnectionError, req.Timeout):
        return []


@pytest.fixture
def db():
    ''' Download reference database from gitlab '''
    database = get_timeout('https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/reference_data/pgsc_calc_ref.sqlar')

    if not database:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
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
    """ Valid chromosomes should be 1 - 22, X, Y, and MT.

    Validity is not checked or enforced """
    return '1'

@pytest.fixture
def valid_pos():
    """ Valid positions are integers. Invalid integers are dropped. """
    return 1234

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
    d = {'rsid' : ['rs11903757', 'rs6061231'], 'chr_name': ['2', '20'], 'chr_position': [191722478, 62381861] }
    return pd.DataFrame(d)

@pytest.fixture
def hg38_to_hg19_coords(hg38_coords):
    ''' A dataframe containing known good coordinates in GRCh37, from dbSNP '''
    d = {'lifted_chr': ['2', '20'], 'lifted_pos': [192587204, 60956917], 'liftover': [True, True] }
    return (hg38_coords.join(pd.DataFrame(d), how = 'outer')
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
def lo_tohg19(chain_files):
    ''' pyliftover object reponsible for converting coordinates hg38 -> hg19 '''
    return LiftOver('hg38ToHg19.over.chain.gz')

@pytest.fixture
def lo_tohg38(chain_files):
    ''' pyliftover object reponsible for converting coordinates hg19 -> hg38 '''
    return LiftOver('hg19ToHg38.over.chain.gz')

@pytest.fixture
def min_lift():
    ''' Minimum proportion of variants to successfully remap coordinates '''
    return 0.95

@pytest.fixture
def scoring_file_noheader():
    ''' Fetch a scorefile without genome build data in the metadata header '''
    scorefile = get_timeout('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000802/ScoringFiles/PGS000802.txt.gz')

    if not scorefile:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
        with open('PGS000802.txt', 'wb') as f:
            f.write(gzip.decompress(scorefile.content))
        yield 'PGS000802.txt'
        os.remove('PGS000802.txt')

@pytest.fixture
def scoring_file_sex():
    """ Fetch a scoring file with X chromosomes """
    scorefile = get_timeout('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000049/ScoringFiles/PGS000049.txt.gz')
    if not scorefile:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
        with open('PGS000049.txt', 'wb') as f:
            f.write(gzip.decompress(scorefile.content))
        yield 'PGS000049.txt'
        os.remove('PGS000049.txt')

@pytest.fixture
def pgs001229():
    scorefile = get_timeout('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS001229/ScoringFiles/PGS001229.txt.gz')

    if not scorefile:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
        with open('PGS001229.txt', 'wb') as f:
            f.write(gzip.decompress(scorefile.content))

        yield 'PGS001229.txt'
        os.remove('PGS001229.txt')

@pytest.fixture
def scoring_file_header():
    ''' Fetch a scorefile with genome build data in the metadata header '''
    scorefile = get_timeout('https://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000777/ScoringFiles/PGS000777.txt.gz')

    if not scorefile:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
        with open('PGS000777.txt', 'wb') as f:
            f.write(gzip.decompress(scorefile.content))

        yield 'PGS000777.txt'
        os.remove('PGS000777.txt')

@pytest.fixture
def scoring_file_noEA(scoring_file_noheader):
    ''' A scoring file (path) with no other allele '''
    f = pd.read_table(scoring_file_noheader, comment = '#')
    f.drop(['effect_allele'], inplace = True, axis = 1)
    f.to_csv('no_ea.txt', sep = '\t', index = False)
    yield 'no_ea.txt'
    os.remove('no_ea.txt')

@pytest.fixture
def scoring_file_noOA(scoring_file_noheader):
    ''' A scoring file (path) with no other allele '''
    f = pd.read_table(scoring_file_noheader, comment = '#')
    f.drop(['other_allele'], inplace = True, axis = 1)
    f.to_csv('no_oa.txt', sep = '\t', index = False)
    yield 'no_oa.txt'
    os.remove('no_oa.txt')

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
            .assign( effect_weight_two = 1.5 ))

@pytest.fixture
def multi_score_file(multi_score_df):
    multi_score_df.to_csv('multi.txt', sep = '\t', index = False)
    yield 'multi.txt'
    os.remove('multi.txt')

@pytest.fixture
def bad_multi_score_file(multi_score_df):
    ''' A scorefile with no effect weights '''
    (multi_score_df.drop(['effect_weight_one', 'effect_weight_two'], axis = 1)
     .to_csv('badmulti.txt', sep = '\t', index = False))
    yield 'badmulti.txt'
    os.remove('badmulti.txt')

@pytest.fixture
def df_cols():
    ''' Expected column names of a parsed scorefile '''
    return { 'chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type' }

@pytest.fixture
def multiple_weights_per_position():
    """ A scorefile with multiple weights per position """
    scorefile = get_timeout('http://ftp.ebi.ac.uk/pub/databases/spot/pgs/scores/PGS000318/ScoringFiles/PGS000318.txt.gz')

    if not scorefile:
        pytest.skip("Couldn't get file from EBI FTP")
    else:
        with open('PGS000318.txt', 'wb') as f:
            f.write(gzip.decompress(scorefile.content))

        yield 'PGS000318.txt'
        os.remove('PGS000318.txt')

def test_valid_chrom_pos(valid_chrom, valid_pos):
    assert to_int(valid_pos) == 1234
    assert parse_lifted_chrom(valid_chrom) == str(1)

def test_annotated_chrom(annotated_chrom):
    assert parse_lifted_chrom(annotated_chrom) == str(22)

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

def test_read_multi_ew(multi_score_file, bad_multi_score_file, multi_score_df):
    x, y = read_scorefile(multi_score_file)

    one = (multi_score_df.loc[:, :'effect_weight_one']
     .rename({'effect_weight_one': 'effect_weight'}, axis = 1))
    two = (multi_score_df.loc[:, :'effect_weight_two']
           .rename({'effect_weight_two': 'effect_weight'}, axis = 1).
           drop(['effect_weight_one'], axis = 1))

    assert len(x) == 2 # different effect weights have been split properly
    assert all(x['one'].loc[:, :'effect_weight'].eq(one))
    assert all(x['two'].loc[:, :'effect_weight'].eq(two))

    with pytest.raises(AssertionError):
        read_scorefile(bad_multi_score_file)


def test_missing_alleles(scoring_file_noEA, scoring_file_noOA):
    """ Test that reading a scorefile without effect alleles
    specified raises an assertion error """

    # missing other allele should be OK
    df_dict, _ = read_scorefile(scoring_file_noOA)
    assert [all(v['other_allele'].isna()) for k, v in df_dict.items()]

    with pytest.raises(AssertionError) as excinfo_ea:
        read_scorefile(scoring_file_noEA)

    assert "Missing" in str(excinfo_ea.value)

def test_write_scorefile(scoring_file_noheader):
    df_dict, _ = read_scorefile(scoring_file_noheader)
    write_scorefile(df_dict, 'scorefile.out')
    assert os.path.exists('scorefile.out')
    x = pd.read_csv('scorefile.out', sep = '\t')

    # is dictionary key correctly set as the accession column?
    assert all(x['accession'] == ''.join(list(df_dict.keys())))

    # is dictinary value equal to the written file?
    assert all(x.drop(['accession'], axis = 1).eq(df_dict['PGS000802']))

    os.remove('scorefile.out')

def test_liftover_summary(pgs001229, hg19, hg38, min_lift, chain_files):
    df, summary = read_scorefile(pgs001229)
    lifted, unlifted = liftover('PGS001229', df['PGS001229'], hg19, hg38, min_lift)
    lifted_dict = {'PGS001229': lifted }
    unlifted_dict = {'PGS001229': unlifted }
    log = liftover_summary(lifted_dict, unlifted_dict, [summary])

    # dicts should be flattened into one big dataframe
    assert isinstance(log, pd.DataFrame)

    # don't lose variants, failed liftover should stay in df
    assert log.shape[0] == df['PGS001229'].shape[0]

    # make sure liftover annotations have been added
    assert {'lifted_pos', 'lifted_chr', 'liftover'}.issubset(log.columns)

    formatted = format_lifted(lifted_dict['PGS001229'])

    # test lifted annotations replace original annotations
    assert formatted[['chr_name', 'chr_position']].equals(lifted_dict['PGS001229'][['lifted_chr', 'lifted_pos']]
                                                       .rename(columns={'lifted_chr': 'chr_name', 'lifted_pos': 'chr_position'}))

    con = sqlite3.connect(':memory:')
    write_log(log, con)

    # make sure log is written to database properly
    assert pd.read_sql("select * from scorefile", con).shape == log.shape

def test_args():
    with pytest.raises(SystemExit):
        # mandatory args: -s, -o
        parse_args(['-s', 'dummy.txt'])

    args = parse_args(['-s', 'dummy.txt', '-o', 'hi.txt'])

    # check optional arg defaults
    assert not args.liftover
    assert not args.target_build
    assert args.min_lift == 0.95

def test_multiple_weights_per_position(multiple_weights_per_position):

    x, _ = read_scorefile(multiple_weights_per_position)

    assert x['PGS000318'].empty, "Scorefile should be filtered out"

def test_read_sex(scoring_file_sex):
    x, _ = read_scorefile(scoring_file_sex)


    assert (x['PGS000049']['chr_name'] == 'X').any(), "X chromosomes missing after reading"
