import pytest
import pandas as pd

import sys
sys.path.append("..")
from bin.samplesheet_to_json import *

@pytest.fixture
def samplesheet():
    ''' A samplesheet dataframe '''
    d = { 'sample': ['cineca_synthetic_subset'], 'vcf_path': [None], 'bfile_path': ['https://gitlab.ebi.ac.uk/nebfield/test-datasets/-/raw/master/pgsc_calc/cineca_synthetic_subset'], 'chrom': [22] }
    return pd.DataFrame(d)

@pytest.fixture
def bad_samplesheet(samplesheet):
    ''' A samplesheet with both vcf path and bfile path '''
    return samplesheet.assign(vcf_path = 'placeholder')

@pytest.fixture
def duplicate_samplesheet(samplesheet):
    return pd.concat([samplesheet, samplesheet])

@pytest.fixture
def csv(samplesheet):
    ''' A path to a csv samplesheet '''
    samplesheet.to_csv('samplesheet.csv', index = False)
    yield 'samplesheet.csv'
    os.remove('samplesheet.csv')

@pytest.fixture
def out(csv):
    main(args = [csv, 'samplesheet.valid.csv'])
    yield 'samplesheet.valid.csv'
    os.remove('samplesheet.valid.csv')

def test_check_samplesheet(csv, out):
    check_samplesheet(csv, out)

def test_check_paths_exclusive(samplesheet, bad_samplesheet):
    check_paths_exclusive(samplesheet)

    with pytest.raises(AssertionError):
        check_paths_exclusive(bad_samplesheet)

def test_check_chrom(samplesheet, duplicate_samplesheet):
    ''' Test asserts about duplicate chromosomes per sample '''
    check_chrom(samplesheet)

    with pytest.raises(AssertionError):
            check_chrom(duplicate_samplesheet)

def test_parse_args(csv, out):
    with pytest.raises(SystemExit):
        parse_args()

    parse_args([csv, out])

def test_main(csv, out):
    main(args = [csv, out])
