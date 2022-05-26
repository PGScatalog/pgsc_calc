#!/usr/bin/env python3

import pandas as pd
import pickle
import sqlite3
import argparse
import sys
import re
from functools import reduce

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-d','--dataset', dest = 'dataset', required = True,
                        help='<Required> Label for target genomic dataset (e.g. "-d thousand_genomes")')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles', required = True,
                        help='<Required> Pickled scorefile path (output of read_scorefiles.py)')
    parser.add_argument('-t','--target', dest = 'target', required = True,
                        help='<Required> A table of target genomic variants (.bim format)')
    parser.add_argument('--split', dest = 'split', default=False, action='store_true',
                        help='<Required> Split scorefile per chromosome?')
    parser.add_argument('-m', '--min_overlap', dest='min_overlap', required=True,
                        type = float, help='<Required> Minimum proportion of variants to match before error')
    return parser.parse_args(args)

def read_scorefiles(pkl):
    ''' Read a pickled dict of dataframes (key: accession, value: scores df) '''
    jar = open(pkl, 'rb')
    scorefiles = pickle.load(jar)
    return scorefiles

def match_ea_ref(scorefile, target):
    """ Match effect allele in scorefile against reference allele in target.

    Parameters:
    scorefile (dataframe): A dataframe containing columns chr_name,
        chr_position, effect_allele, other_allele, and effect weight.
    target (dataframe): Containing columns #CHROM, POS, REF, ALT (the same
        columns as a plink variant information file, e.g. bim or pvar)

    Returns:
        A dataframe with rows intersecting position and alleles, and columns merged
    """
    return pd.merge(scorefile, target, how = 'inner', left_on = ['chr_name', \
        'chr_position', 'effect_allele', 'other_allele'], right_on = ['#CHROM', \
        'POS', 'REF', 'ALT'], validate = '1:1', suffixes=(False, False))

def match_ea_alt(scorefile, target):
    """ Match effect allele in scorefile against alternate allele in target.

    Parameters:
    scorefile (dataframe): A dataframe containing columns chr_name,
        chr_position, effect_allele, other_allele, and effect weight.
    target (dataframe): Containing columns #CHROM, POS, REF, ALT (the same
        columns as a plink variant information file, e.g. bim or pvar)

    Returns:
        A dataframe with rows intersecting position and alleles, and columns merged
    """
    # EA = ALT and OA = REF
    return pd.merge(scorefile, target, how = 'inner', left_on = ['chr_name', \
        'chr_position', 'effect_allele', 'other_allele'], right_on = ['#CHROM', \
        'POS', 'ALT', 'REF'], validate = '1:1', suffixes=(False, False))

def complement(s):
    ''' Complement a string of nucleotides '''
    basecomplement = {'A': 'T', 'C': 'G', 'G': 'C', 'T': 'A'}
    letters = list(s)
    letters = [basecomplement[base] for base in letters]
    return ''.join(letters)

def match_variants(scorefile, target, accession, con):
    """ Match variants in a scorefile against target variant information

    Matching can be done by:
        - Simple direct matching of positions and alleles
        - Take unmatched alleles and try matching after complementing
    Logs of the matching process are stored in a persistent database

    Parameters:
    scorefile: A dataframe containing columns chr_name, chr_position,
        effect_allele, other_allele, effect_weight, and effect_type
    target: A dataframe containing columns #CHROM, POS, REF, and ALT
    accession: A unique identifier associated with a scorefile, e.g. "PGS001229"
    con: A sqlite database connection used to store matches and statistics
    """
    standard_match = (
        match_ea_ref(scorefile, target).append(match_ea_alt(scorefile, target))
        .assign(match_type='standard', accession = accession)
    )

    unmatched = (
        pd.merge(standard_match, scorefile, how = 'outer', indicator = True)
        .query('_merge == "right_only"')
        .loc[:, ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type']]
    )

    flip_match = (
        match_flipped(unmatched, target)
        .assign(match_type='flipped', accession = accession)
    )

    matches = standard_match.append(flip_match)

    matches.to_sql('matches', con, if_exists = 'append', index = False)

    (
        pd.DataFrame(data = { 'accession': [accession], 'n_target': [target.shape[0]], 'n_scorefile': [scorefile.shape[0]] })
        .to_sql('meta', con, if_exists = 'append', index = False)
    )

    return ( matches
      .loc[:, ['ID', 'effect_allele',  'effect_weight', 'effect_type']]
      .rename( columns = { 'effect_weight': accession })
    )

def match_flipped(unmatched, target):
    """ Match complemented effect allele from scorefile against target genomic variants.

    Parameters:
    unmatched (dataframe): A dataframe containing unmatched variants, with
        columns chr_name, chr_position, effect_allele, other_allele, and effect
        weight.
    target (dataframe): Containing columns #CHROM, POS, REF, ALT (the same
        columns as a plink variant information file, e.g. bim or pvar)

    Returns:
        A dataframe with rows intersecting position and alleles, and columns merged
    """
    complemented = [x.map(complement) for x in [unmatched['effect_allele'], unmatched['other_allele']]]
    complemented.append(unmatched.drop(['effect_allele', 'other_allele'], axis = 1))
    unmatched_flipped = pd.concat(complemented, axis = 1)

    return match_ea_ref(unmatched_flipped, target).append(match_ea_alt(unmatched_flipped, target))

def merge_scorefiles(x, y):
    ''' Combine multiple scoring files by appending effect weight columns '''
    return x.merge(y, on = ['ID', 'effect_allele', 'effect_type'], how = 'outer')

def split_effect_type(df):
    ''' Split scorefile variant rows into subsets by effect type '''
    grouped = df.groupby('effect_type')
    return { k: grouped.get_group(k).drop('effect_type', axis = 1 ) for k, v in
        grouped.groups.items() }

def unduplicate_variants(df):
    """ Find variant matches that have duplicate identifiers

    When merging a lot of scoring files, sometimes a variant might be duplicated
    this can happen when the effect allele differs at the same position, e.g.:
        - chr1: chr2:20003:A:C A 0.3 NA
        - chr1: chr2:20003:A:C C NA 0.7
    where the last two columns represent different scores.  plink demands
    unique identifiers! so need to split, score, and sum later

    Parameters:
    df: A dataframe containing all matches, with columns ID, effect_allele, and
        effect_weight

    Returns:
    A dict with two keys:
        - 'ea_ref': A dataframe containing unique variant identifiers
        - 'ea_alt': A dataframe containing the duplicated variant identifiers
    """
    ea_ref = ~df.duplicated(subset=['ID'], keep='first')
    ea_alt = ~ea_ref
    return { 'ea_ref': df[ea_ref], 'ea_alt': df[ea_alt] }

def write_scorefiles(effect_type, scorefile, split):
    """ Write a merged scorefile to valid plink2 scorefile format

    Multiple scores stored in separate scorefiles can be merged (merging
    columns) to process many scores in parallel. A valid scorefile must contain
    variants with the same effect type and cannot contain duplicate variant
    identifiers. Optionally, output scorefiles should reflect the input target
    data's split state. Large target datasets may be split to process
    chromosomes in parallel. If unsplit scorefiles are used on split target
    genomes, then warnings are produced by plink2. Let's fix it and be polite.

    Parameters:
    effect_type: The effect type associated with the scorefile (additive,
        dominant, or recessive)
    scorefile: The merged scorefile, maybe containing multiple scores in
        additional columns
    split: Should output files be split by chromosome?

    Returns:
    None, a set of scorefiles are written to disk.
    """

    fout = 'false_{et}_{dup}.scorefile'

    if not scorefile.get('ea_ref').empty:
        df = scorefile.get('ea_ref')
        if split:
            write_split(split_scorefile(df), effect_type, '0')
        else:
            df.fillna(0).to_csv(fout.format(et = effect_type, dup = '0'), sep = '\t', index = False)

    if not scorefile.get('ea_alt').empty:
        df = scorefile.get('ea_alt')
        if split:
            write_split(split_scorefile(df), effect_type, '1')
        else:
            df.fillna(0).to_csv(fout.format(et = effect_type, dup = '1'), sep = '\t', index = False)

def write_split(split_dfs, effect_type, dup):
    ''' Write a dict of dataframes to files with appropriate names '''
    split_fout = '{chr}_{et}_{dup}.scorefile'

    [df.fillna(0).to_csv(split_fout.format(chr = k, et = effect_type, dup = dup), \
               sep = '\t', index = False) for k, df in split_dfs.items()]

def split_scorefile(df):
    ''' Split a combined scorefile into a dict of dataframes (subset by chrom) '''
    df[['chr', 'pos', 'ref', 'alt']] = df['ID'].str.split(':', 4, expand = True)
    return { chrom: split_df.drop(columns = ['chr', 'pos', 'ref', 'alt']) for \
             chrom, split_df in df.groupby('chr')}

def make_report(conn, min_overlap):
    """ Make a table of summary statistics about the matching process

    Parameters:
    conn: A connection to the match sqlite database
    min_overlap (float): The minimum proportion of variants that should match
        from the scoring file to the target genomic data

    Returns:
    None, the table is written to report.csv
    """
    report = pd.read_sql('select * from matches', conn)
    log = pd.read_sql('select * from meta', conn)

    stats = (
        pd.DataFrame(report.groupby(['accession']).size(), columns = ['matches'])
        .reset_index()
        .merge(log, on = ['accession'])
        .assign(prop_matched = lambda x: x['matches'] / x['n_scorefile'],
                min_overlap = min_overlap,
                pass_filter = lambda x: x['prop_matched'] >= x['min_overlap'])
    )

    stats.to_csv('report.csv', index = False)

    for index, row in stats.iterrows():
        match_error = '''
            MATCH ERROR: Scorefile {} doesn't match target genomes well
            Minimum overlap: {:.2%}
            Scorefile match: {:.2%}
        '''.format(row['accession'], row['min_overlap'], row['prop_matched'])

        assert row['pass_filter'], match_error

def read_target(path):
    ''' Read a pvar or a bim file and set a standard pvar header '''

    with open(path) as f:
        line = f.readline()
        if re.search("^#", line):
            pvar = True
        else:
            pvar = False

    if (pvar):
        return pd.read_csv(path, sep = '\t')
    else:
        return (pd.read_csv(path, sep = '\t', header = None)
                .rename({0: '#CHROM', 1: 'ID', 2: 'CM', 3: 'POS', 4: 'REF', 5: 'ALT'}, axis = 1))

def main(args = None):
    ''' Match variants from scorefiles against target variant information '''

    args = parse_args(args)

    # read inputs and set up database for logging-------------------------------
    target = read_target(args.target)

    unpickled_scorefiles = read_scorefiles(args.scorefiles) # { accession: df }
    conn = sqlite3.connect('match_variants.db')

    pd.DataFrame.from_dict( { 'id': [args.dataset] }).to_sql('id', conn, index = False)

    # start matching :) --------------------------------------------------------
    matched_scorefiles = [match_variants(v, target, k, conn) for k, v in unpickled_scorefiles.items()]

    empty_match = [x.empty for x in matched_scorefiles]
    empty_err = ''' ERROR: No target variants match any variants in all scoring files
    This is quite odd!
    Try checking the genome build (see --liftover and --target_build parameters)
    Try imputing your microarray data if it doesn't cover the scoring variants well
    '''
    assert not all(empty_match), empty_err

    # process matched variants: merge, split by effect type, and unduplicate ---
    merged_scorefile = reduce(lambda x, y: x.merge(y, on = ['ID', 'effect_allele', \
        'effect_type'], how = 'outer'), matched_scorefiles)
    split_effects = split_effect_type(merged_scorefile)
    unduplicated = { k: unduplicate_variants(v) for k, v in split_effects.items() }

    # write matched and processed variants out, with a report -------------------
    # "is_" breaks output naming scheme (chr_effecttype_dup)
    ea_dict = { 'is_dominant': 'dominant', 'is_recessive': 'recessive', 'additive': 'additive'}

    [write_scorefiles(ea_dict.get(k), v, args.split) for k, v in unduplicated.items() ]

    make_report(conn, args.min_overlap)

if __name__ == '__main__':
    sys.exit(main())
