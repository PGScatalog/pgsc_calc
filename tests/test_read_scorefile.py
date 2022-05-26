import pytest
import numpy as np
import pandas as pd
from pyliftover import LiftOver
from bin.read_scorefile import to_int
from bin.read_scorefile import parse_lifted_chrom
from bin.read_scorefile import convert_coordinates

@pytest.fixture
def valid_chrom():
    return 1

@pytest.fixture
def invalid_chrom():
    return "random string"

@pytest.fixture
def annotated_chrom():
    return "22_annotations_that_are_annoying"

@pytest.fixture
def hg38_coords():
    # random variants from PGS000802, pos in GRCh38 (dbSNP)
    d = {'rsid' : ['rs11903757', 'rs6061231'], 'chr_name': [2, 20], 'chr_position': [191722478, 62381861] }
    return pd.DataFrame(d)

@pytest.fixture
def hg38_to_hg19_coords(hg38_coords):
    # two additional columns, chr and pos now in GRCh37 (from dbSNP)
    d = {'lifted_chr': [2, 20], 'lifted_pos': [192587204, 60956917] }
    return hg38_coords.join(pd.DataFrame(d, dtype = 'Int64'), how = 'outer')

@pytest.fixture
def hg19_unique_coords():
    # these coordinates won't map from hg19 -> hg38 (deleted)
    d = {'chr_name': [22, 22, 22], 'chr_position': [22561610, 23412058, 28016883]}
    return pd.DataFrame(d)

@pytest.fixture
def lo_tohg19():
    return LiftOver('hg38', 'hg19')

@pytest.fixture
def lo_tohg38():
    return LiftOver('hg19', 'hg38')

def test_valid_chrom(valid_chrom):
    assert to_int(valid_chrom) == 1
    assert parse_lifted_chrom(valid_chrom) == 1

def test_invalid_chrom(invalid_chrom):
    assert np.isnan(to_int(invalid_chrom)) # why is this behaviour different?
    assert parse_lifted_chrom(invalid_chrom) is None

def test_annotated_chrom(annotated_chrom):
    assert parse_lifted_chrom(annotated_chrom) == 22

def test_liftover(hg38_coords, lo_tohg19, lo_tohg38, hg38_to_hg19_coords, hg19_unique_coords):
    # test valid positions are mapped from (GRCh38 -> GRCh37)
    hg38_coords[['lifted_chr', 'lifted_pos']] = hg38_coords.apply(lambda x: convert_coordinates(x, lo_tohg19), axis = 1)
    assert hg38_coords.equals(hg38_to_hg19_coords)

    # test invalid positions that won't map (GRCh37 -> GRCh38)
    assert (hg19_unique_coords
        .apply(lambda x: convert_coordinates(x, lo_tohg38), axis = 1)
        .isnull()
        .all(axis=None)
            )
