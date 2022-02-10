#!/usr/bin/env python3

import pandas as pd
import pickle
import sqlite3
import argparse
import sys
from functools import reduce

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles',
                        help='<Required> Pickled scorefile path (output of read_scorefiles.py)', required=True)
    parser.add_argument('-t','--target', dest = 'target',
                        help='<Required> A table of target genomic variants (.bim format)', required=True)
    parser.add_argument('-m', '--min_overlap', dest='min_overlap', required=True,
                        help='<Required> Minimum proportion of variants to match before error', type = float)
    return parser.parse_args()

def read_scorefiles(pkl):
    jar = open(pkl, "rb")
    scorefiles = pickle.load(jar)
    return scorefiles

def match_ea_ref(scorefile, target):
    # EA = REF and OA = ALT
    return pd.merge(scorefile, target, how = "inner", left_on = ["chr_name", \
        "chr_position", "effect_allele", "other_allele"], right_on = ["#CHROM", \
        "POS", "REF", "ALT"], validate = "1:1", suffixes=(False, False))

def match_ea_alt(scorefile, target):
    # EA = ALT and OA = REF
    return pd.merge(scorefile, target, how = "inner", left_on = ["chr_name", \
        "chr_position", "effect_allele", "other_allele"], right_on = ["#CHROM", \
        "POS", "ALT", "REF"], validate = "1:1", suffixes=(False, False))

def complement(s):
    basecomplement = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A'}
    letters = list(s)
    letters = [basecomplement[base] for base in letters]
    return ''.join(letters)

def match_variants(scorefile, target, accession, con):
    standard_match = (
        match_ea_ref(scorefile, target).append(match_ea_alt(scorefile, target))
        .assign(match_type="standard", accession = accession)
    )

    unmatched = (
        pd.merge(standard_match, scorefile, how = "outer", indicator = True)
        .query('_merge == "right_only"')
        .loc[:, ["chr_name", "chr_position", "effect_allele", "other_allele", "effect_weight", "effect_type"]]
    )

    flip_match = (
        match_flipped(unmatched, target)
        .assign(match_type="flipped", accession = accession)
    )

    matches = standard_match.append(flip_match)

    # log matches
    matches.to_sql("matches", con, if_exists = "append", index = False)

    # log metadata
    (
        pd.DataFrame(data = { 'accession': [accession], 'n_target': [target.shape[0]], 'n_scorefile': [scorefile.shape[0]] })
        .to_sql("meta", con, if_exists = "append", index = False)
    )

    return ( matches
      .loc[:, ["ID", "effect_allele",  "effect_weight", "effect_type"]]
      .rename( columns = { 'effect_weight': accession })
    )

def match_flipped(unmatched, target):
    # complement both alleles and add to the unmatched variants in the scorefile
    complemented = [x.map(complement) for x in [unmatched['effect_allele'], unmatched['other_allele']]]
    complemented.append(unmatched.drop(['effect_allele', 'other_allele'], axis = 1))
    unmatched_flipped = pd.concat(complemented, axis = 1)

    return match_ea_ref(unmatched_flipped, target).append(match_ea_alt(unmatched_flipped, target))

def read_scorefiles(pkl):
    jar = open(pkl, "rb")
    scorefiles = pickle.load(jar)
    return scorefiles

def merge_scorefiles(x, y):
    return x.merge(y, on = ['ID', 'effect_allele', 'effect_type'], how = 'outer')

def split_effect_type(df):
    # split df by effect type (additive, dominant, or recessive) into a dict of
    # dfs
    grouped = df.groupby('effect_type')
    return { k: grouped.get_group(k).drop('effect_type', axis = 1 ) for k, v in
        grouped.groups.items() }

def unduplicate_variants(df):
    # when merging a lot of scoring files, sometimes a variant might be duplicated
    # this can happen when the effect allele differs at the same position, e.g.:
    #     - chr1: chr2:20003:A:C A 0.3 NA
    #     - chr1: chr2:20003:A:C C NA 0.7
    # where the last two columns represent different scores.  plink demands
    # unique identifiers! so need to split, score, and sum later

    # .duplicated() marks first duplicate element as True
    # cats, cats, dogs -> False, True, False
    ea_ref = ~df.duplicated(subset=['ID'], keep='first')
    ea_alt = ~ea_ref
    # ~ negates for getting a subset of rows with a boolean series
    return { 'ea_ref': df[ea_ref], 'ea_alt': df[ea_alt] }

def write_scorefiles(effect_type, scorefile):
    fout = "{}_{}.scorefile"

    if not scorefile.get('ea_ref').empty:
        df = scorefile.get('ea_ref')
        df.to_csv(fout.format(effect_type, "first"), sep = "\t", index = False)
    if not scorefile.get('ea_alt').empty:
        df = scorefile.get('ea_alt')
        df.to_csv(fout.format(effect_type, "second"), sep = "\t", index = False)

def make_report(conn, min_overlap):
    report = pd.read_sql("select * from matches", conn)
    log = pd.read_sql("select * from meta", conn)

    stats = (
        pd.DataFrame(report.groupby(['accession']).size(), columns = ["matches"])
        .reset_index()
        .merge(log, on = ["accession"])
        .assign(prop_matched = lambda x: x['matches'] / x['n_scorefile'],
                min_overlap = min_overlap,
                pass_filter = lambda x: x['prop_matched'] >= x['min_overlap'])
    )

    stats.to_csv("report.csv", index = False)

    for index, row in stats.iterrows():
        match_error = """
            MATCH ERROR: Scorefile {} doesn't match target genomes well
            Minimum overlap: {:.2%}
            Scorefile match: {:.2%}
        """.format(row['accession'], row['min_overlap'], row['prop_matched'])

        assert row['pass_filter'], match_error

def main(args = None):
    args = parse_args(args)
    # read inputs and set up database for logging-------------------------------
    target = pd.read_csv(args.target, sep = "\t")
    unpickled_scorefiles = read_scorefiles(args.scorefiles) # { accession: df }
    conn = sqlite3.connect('match_variants.db')

    # start matching :) --------------------------------------------------------
    matched_scorefiles = [match_variants(v, target, k, conn) for k, v in unpickled_scorefiles.items()]

    # process matched variants: merge, split by effect type, and unduplicate ---
    merged_scorefile = reduce(lambda x, y: x.merge(y, on = ['ID', 'effect_allele', \
        'effect_type'], how = 'outer'), matched_scorefiles)
    split_effects = split_effect_type(merged_scorefile)
    unduplicated = { k: unduplicate_variants(v) for k, v in split_effects.items() }

    # write matched and processed variants out, with a report -------------------
    [write_scorefiles(k, v) for k, v in unduplicated.items() ]

    make_report(conn, args.min_overlap)

if __name__ == "__main__":
    sys.exit(main())

# TO DO ========================================================================
# TO DO: double check ambiguous alleles??
