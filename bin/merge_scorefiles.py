#!/usr/bin/env python3

import numpy as np
import pandas as pd
import argparse
import os.path
from functools import reduce

parser = argparse.ArgumentParser(description='Combine scoring files')
parser.add_argument('-s','--scorefiles', dest = 'scorefiles', nargs='+',
    help='<Required> Scorefile path (wildcard * is OK)', required=True)
parser.add_argument('-o', '--outfile', dest = 'outfile', required = True,
    help = '<Required> Merged scorefile output path')
args = parser.parse_args()

def to_int(i):
    # convert non-numeric chromosomes or positions to NaN
    try:
        return int(i)
    except ValueError:
        return np.nan

def read_scorefile(path):
    # example filename: PGS000001_checked.txt
    # example data structure:
    # chr_name | chr_position | effect_allele | other_allele | effect_weight
    # 1        | 1234         | A             | C            | 1.05
    accession = os.path.basename(path).split('_')[0]
    convert = { 'chr_name': to_int, 'chr_pos': to_int }
    x = pd.read_table(path, converters = convert)
    x.rename(columns = {"effect_weight":accession}, inplace = True)
    x.dropna(subset = ['chr_name', 'chr_position'], inplace = True)
    x[['chr_name', 'chr_position']] = x[['chr_name', 'chr_position']].astype(int)
    return x

def merge_scorefiles(x, y):
    # need to combine multiple scorefile weights, adding a column for each
    # scorefile. it's equivalent to an outer join, because variants (rows) have
    # to be matched across scorefiles and NAs are good if a variant isn't
    # present
    # example inputs:
    #     dataframe 1:
    #         chr_name | chr_position | effect_allele | other_allele | weight_1
    #     dataframe 2:
    #         chr_name | chr_position | effect_allele | other_allele | weight_n
    # example output:
    # chr_name | chr_position | effect_allele | other_allele | weight_1 | weight_n
    return x.merge(y, on = ['chr_name', 'chr_position', 'effect_allele', 'other_allele'], how = 'outer')

def join_scorefiles(args):
    scorefiles = [read_scorefile(x) for x in args.scorefiles]
    merged = reduce(merge_scorefiles, scorefiles)
    merged.to_csv(args.outfile, sep = "\t", index = False)

if __name__ == "__main__":
    join_scorefiles(args)
