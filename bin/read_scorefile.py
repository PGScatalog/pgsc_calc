#!/usr/bin/env python3

import numpy as np
import pandas as pd
import argparse
import os.path
import sys
import pickle
import re
from functools import reduce

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles', nargs='+',
                        help='<Required> Scorefile path (wildcard * is OK)', required=True)
    parser.add_argument('-o', '--outfile', dest = 'outfile', required = False,
                        default = 'scorefiles.pkl',
                        help = '<Required> Output path to pickled list of scorefiles, e.g. scorefiles.pkl')
    return parser.parse_args()

def to_int(i):
    ''' Convert non-numeric chromosomes or positions to NaN '''
    try:
        return int(i)
    except ValueError:
        return np.nan

def set_effect_type(x, path):
    ''' Do error checking and extract effect type from single effect weight scorefile '''
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

        truth_error = ''' ERROR: Bad scorefile {}
        is_recessive and is_dominant columns are both TRUE for a variant
        These columns are mutually exclusive (both can't be true)
        Both can be FALSE for additive variant scores
        '''
        assert not x[['is_dominant', 'is_recessive']].all(axis = 1).any(), truth_error.format(path)

        scorefile = (
            x[mandatory_columns]
            .assign(additive = lambda x: (x["is_recessive"] == False) & (x["is_dominant"] == False))
            .assign(effect_type = lambda df: df[["is_recessive", "is_dominant", "additive"]].idxmax(1))
            .drop(["is_recessive", "is_dominant", "additive"], axis = 1)
        )
    return scorefile

def quality_control(accession, df):
    ''' Do basic error checking and quality control on scorefile variants '''

    qc = (
        df.query('effect_allele != "P" | effect_allele != "N"')
        .dropna(subset = ['chr_name', 'chr_position', 'effect_weight'])
    )

    unique_err = ''' ERROR: Bad scorefile "{}"
    Duplicate variant identifiers in scorefile (chr:pos:effect:other)
    Please use only unique variants and try again!
    '''

    unique_df = qc.groupby(['chr_name', 'chr_position', 'effect_allele', 'other_allele']).size() == 1
    assert unique_df.all(), unique_err.format(accession)

    return qc

def read_scorefile(path):
    ''' Read essential information from a scorefile '''

    x = pd.read_table(path, converters = { "chr_name": to_int, "chr_pos": to_int
                                           }, comment = "#")

    assert len(x.columns) > 1, "ERROR: scorefile not formatted correctly"
    assert { 'chr_name', 'chr_position' }.issubset(x.columns), "ERROR: Need chr_position and chr_name (rsids not supported yet!)"

    # nullable int is always important
    x[["chr_name", "chr_position"]] = x[["chr_name", "chr_position"]].astype(pd.Int64Dtype())

    # check for a single effect weight column called 'effect_weight'
    columns = [re.search("^effect_weight$", x) for x in x.columns.to_list()]
    if any(col is not None for col in columns):
        # scorefiles with a single effect weight column might have effect types
        accession = os.path.basename(path).split('.')[0]
        scorefile = { accession: set_effect_type(x, path) }
    else:
        # otherwise effect weights have a suffix e.g. effect_weight_PGS0001
        # need to process these differently
        scorefile = multi_ew(x)

    # TODO: do stats before...
    qc_scorefile = { k: quality_control(k, v) for k, v in scorefile.items() }
    # TODO: and after...

    return qc_scorefile

def stats(scorefile):
    ''' Write important statistics to a database '''
    pass

def multi_ew(x):
    ''' Split a scorefile with multiple effect weights into a dict of dfs '''

    # different mandatory columns for multi score (effect weight has a suffix)
    mandatory_columns = ["chr_name", "chr_position", "effect_allele", "other_allele"]
    col_error = "ERROR: Missing mandatory columns"
    assert set(mandatory_columns).issubset(x.columns), col_error

    ew_cols = x.filter(regex=("effect_weight_*")).columns.to_list()
    accessions = [x.split('_')[-1] for x in ew_cols]
    split_scores = [
        (x.filter(items = mandatory_columns + [ew])
         .rename(columns = { ew: 'effect_weight' })
         .assign(effect_type = 'additive')
         )
        for ew in ew_cols]

    return dict(zip(accessions, split_scores))

def main(args = None):
    args = parse_args(args)
    scorefiles = [read_scorefile(x) for x in args.scorefiles]

    with open(args.outfile, 'wb') as f:
        pickle.dump(reduce(lambda x, y: { **x, **y }, scorefiles), f)

if __name__ == "__main__":
    sys.exit(main())
