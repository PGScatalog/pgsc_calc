#!/usr/bin/env python3

import numpy as np
import pandas as pd
import argparse
import os.path
import sys
import pickle

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles', nargs='+',
                        help='<Required> Scorefile path (wildcard * is OK)', required=True)
    parser.add_argument('-o', '--outfile', dest = 'outfile', required = False,
                        default = 'scorefiles.pkl',
                        help = '<Required> Output path to pickled list of scorefiles, e.g. scorefiles.pkl')
    return parser.parse_args()

def to_int(i):
    # convert non-numeric chromosomes or positions to NaN
    try:
        return int(i)
    except ValueError:
        return np.nan

def set_effect_type(x):
    mandatory_columns = ["chr_name", "chr_position", "effect_allele", "other_allele", "effect_weight"]
    col_error = "ERROR: Missing mandatory columns"

    if not { 'is_recessive', 'is_dominant' }.issubset(x.columns):
        assert set(mandatory_columns).issubset(x.columns), col_error
        scorefile = (
            x[mandatory_columns]
            .assign(effect_type = 'additive') # default effect type
        )
    else:
        mandatory_columns.extend(["is_recessive", "is_dominant"])
        assert set(mandatory_columns).issubset(x.columns), col_error
        scorefile = (
            x[mandatory_columns]
            .assign(additive = lambda x: (x["is_recessive"] == False) & (x["is_dominant"] == False))
            .assign(effect_type = lambda df: df[["is_recessive", "is_dominant", "additive"]].idxmax(1))
            .drop(["is_recessive", "is_dominant", "additive"], axis = 1)
        )
    return scorefile

def quality_control(df):
    return (
        df.query('effect_allele != "P" | effect_allele != "N"')
        .dropna(subset = ['chr_name', 'chr_position'])
    )

def read_scorefile(path):
    x = pd.read_table(path, converters = { "chr_name": to_int, "chr_pos": to_int
                                           }, comment = "#")

    assert { 'chr_name', 'chr_position' }.issubset(x.columns), "ERROR: Need chr_position and chr_name (rsids not supported yet!)"

    # nullable int is always important
    x[["chr_name", "chr_position"]] = x[["chr_name", "chr_position"]].astype(pd.Int64Dtype())

    scorefile = set_effect_type(x) # e.g. additive, recessive
    qc_scorefile = quality_control(scorefile)

    return qc_scorefile

def main(args = None):
    args = parse_args(args)
    accessions = [os.path.basename(x).split('.')[0] for x in args.scorefiles]
    scorefiles = [read_scorefile(x) for x in args.scorefiles]
    score_dict = dict(zip(accessions, scorefiles)) # key: accession, value: df

    with open(args.outfile, 'wb') as f:
        pickle.dump(score_dict, f)

if __name__ == "__main__":
    sys.exit(main())
