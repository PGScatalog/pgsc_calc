#!/usr/bin/env python3

import numpy as np
import pandas as pd
import argparse
import os.path
import sys
import pickle
import re
import gzip
import io
import sqlite3
from functools import reduce
from pyliftover import LiftOver

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles', nargs='+',
                        help='<Required> Scorefile path (wildcard * is OK)', required=True)
    parser.add_argument('--liftover', dest='liftover',
                        help='<Optional> Convert scoring file variants to target genome build?', action='store_true')
    parser.add_argument('-t', '--target_build', dest = 'target_build', help='Build of target genome <GRCh37 / GRCh38>',
                        required='--liftover' in sys.argv)
    parser.add_argument('-m', '--min_lift', dest = 'min_lift', help='<Optional> If liftover, minimum proportion of variants lifted over',
                        default = 0.95, type = float)
    parser.add_argument('-o', '--outfile', dest = 'outfile', required = True,
                        default = 'scorefiles.pkl',
                        help = '<Required> Output path to pickled list of scorefiles, e.g. scorefiles.pkl')
    return parser.parse_args(args)

def to_int(i):
    ''' Convert non-numeric chromosomes or positions to NaN '''
    try:
        return int(i)
    except ValueError:
        return None

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

def score_summary(raw, qc):
    ''' Concatenate and label raw input scores if they pass / fail QC '''
    idx = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type', 'accession']
    raw_scores = pd.concat([v.assign(accession = k) for k, v in raw.items()])
    qc_scores = pd.concat([v.assign(accession = k) for k, v in qc.items()])
    # outer join to find raw scores missing from QC and then label with fail
    return (qc_scores
        .assign(qc = True)
        .join(raw_scores.set_index(idx), on = idx, how = 'outer')
        .fillna(value = {'qc': False}))

def read_scorefile(path):
    ''' Read essential information from a scorefile '''

    x = pd.read_table(path, converters = { "chr_name": to_int, "chr_pos": to_int
                                           }, comment = "#")

    assert len(x.columns) > 1, "ERROR: scorefile not formatted correctly"
    assert { 'chr_name', 'chr_position' }.issubset(x.columns), "ERROR: Need chr_position and chr_name (rsids not supported yet!)"
    assert { 'effect_allele', 'other_allele' }.issubset(x.columns), "ERROR: Missing effect / other allele columns"

    # nullable int is always important
    x[["chr_name", "chr_position"]] = x[["chr_name", "chr_position"]].astype(pd.Int64Dtype())

    # check for a single effect weight column called 'effect_weight'
    columns = [re.search("^effect_weight$", x) for x in x.columns.to_list()]
    columns_suffix = [re.search("^effect_weight_[A-Za-z0-9]+$", x) for x in x.columns.to_list()]

    if any(col is not None for col in columns):
        # scorefiles with a single effect weight column might have effect types
        accession = get_accession(path)
        scorefile = { accession: set_effect_type(x, path) }
    elif any(col is not None for col in columns_suffix):
        # otherwise effect weights have a suffix e.g. effect_weight_PGS0001
        # need to process these differently
        scorefile = multi_ew(x)
    else:
        assert 0, "ERROR: Missing valid effect weight columns"

    qc_scorefile = { k: quality_control(k, v) for k, v in scorefile.items() }

    return qc_scorefile, score_summary(scorefile, qc_scorefile)

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

def parse_lifted_chrom(i):
    """ Convert lifted chromosomes to tidy integers

    liftover needs chr suffix for chromosome input (1 -> chr1), and it also
    returns weird chromosomes sometimes (chr22 -> 22_KI270879v1_alt)
    """
    try:
        return int(i)
    except ValueError:
        try:
            return int(i.split('_')[0])
        except ValueError:
            return None

def convert_coordinates(df, lo):
    ''' Convert genomic coordinates to different build '''
    chrom = 'chr' + str(df['chr_name'])
    pos = int(df['chr_position']) - 1 # liftOver is 0 indexed, VCF is 1 indexed
    converted = lo.convert_coordinate(chrom, pos)

    if converted:
        # return first matching liftover
        lifted_chrom = parse_lifted_chrom(converted[0][0][3:])
        lifted_pos = int(converted[0][1]) + 1 # reverse 0 indexing
        return pd.Series([lifted_chrom, lifted_pos], dtype = 'Int64')
    else:
        return pd.Series([None, None], dtype = 'Int64')

def liftover(accession, df, from_build, to_build, min_lift):
    ''' Update scorefile dataframe with lifted coordinates '''
    build_dict = {'GRCh37':'hg19', 'GRCh38':'hg38', 'hg19': 'hg19', 'hg18':'hg18'}

    if (build_dict[from_build] == build_dict[to_build]):
        df[['lifted_chr', 'lifted_pos']] = df[['chr_name', 'chr_position']]
        mapped = df.assign(liftover = None)
        unmapped = df.assign(liftover = None)[0:0] # just keep col structure

        return mapped, unmapped
    else:
        lo = LiftOver(build_dict[from_build], build_dict[to_build])
        df[['lifted_chr', 'lifted_pos']] = df.apply(lambda x: convert_coordinates(x, lo), axis = 1)
        mapped = df[~df.isnull().any(axis = 1)].assign(liftover = True)
        unmapped = df[df.isnull().any(axis = 1)].assign(liftover = False)
        check_liftover({'mapped': mapped, 'unmapped': unmapped}, accession, min_lift)

        return mapped, unmapped

def check_liftover(df_dict, accession, min_lift):
    ''' Write liftover statistics to a database '''
    n_mapped = df_dict['mapped'].shape[0]
    n_unmapped = df_dict['unmapped'].shape[0]
    total = n_mapped + n_unmapped

    err = "ERROR: Liftover failed for {}, see --min-lift parameter".format(accession)
    assert n_mapped / total > min_lift, err

def read_build(path):
    ''' Open scorefiles and automatically handle compressed input '''
    try:
        with io.TextIOWrapper(io.BufferedReader(gzip.open(path, 'r'))) as f:
            return read_header(f)
    except gzip.BadGzipFile:
        with open(path, 'r') as f:
            return read_header(f)

def read_header(f):
    ''' Extract genome build of scorefile from PGS Catalog header format '''
    build_dict = {'GRCh37':'hg19', 'GRCh38':'hg38', 'hg19':'hg19', 'hg38':'hg38'}
    for line in f:
        if re.search("^#genome_build", line):
            # get #genome_build=GRCh37 from header
            header = line.replace('\n', '').replace('#', '').split('=')
            # and remap to liftover style
            try:
                return build_dict[header[-1]]
            except KeyError:
                return None # bad genome build
        elif (line[0] != '#'):
            # genome build isn't set in header :( stop the loop and cry
            return None

def get_accession(path):
    ''' Return the basename of a scoring file without extension '''
    return os.path.basename(path).split('.')[0]

def check_build(accession, build):
    ''' Verify a valid build was specified in the scoring file header '''
    build_err = ''' ERROR: Build not specified in scoring file header
    Please check file: {}
    Valid header examples:
    #genome_build=GRCh37
    #genome_build=GRCh38'''.format(accession)

    assert build is not None, build_err

def write_pickle(x, outfile):
    ''' Serialise an object to file '''
    with open(outfile, 'wb') as f:
        pickle.dump(x, f)

def liftover_summary(lifted_dict, unlifted_dict, scorefile_summaries):
    """ Flatten dataframes collections and add liftover status (_chr, _pos).

        Schema:

            chr_name          object
            chr_position      object
            effect_allele     object
            other_allele      object
            effect_weight    float64
            effect_type       object
            accession         object
            qc                  bool
            lifted_chr         Int64
            lifted_pos         Int64
            liftover            bool
    """

    summary = pd.concat(scorefile_summaries)
    lifted = pd.concat([v.assign(accession = k) for k, v in lifted_dict.items()])
    unlifted = pd.concat([v.assign(accession = k) for k, v in unlifted_dict.items()])
    liftover = pd.concat([lifted, unlifted])

    idx = ['accession', 'chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type']
    return (summary.merge(liftover, on = idx))

def format_lifted(lifted):
    ''' Replace original positions with lifted data for matching variants '''
    formatted = (lifted
        .drop(['chr_position', 'chr_name', 'liftover'], axis = 1)
        .rename(columns = {'lifted_chr': 'chr_name', 'lifted_pos': 'chr_position'}))
    return formatted[['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type']]

def write_log(df, conn):
    """ Write log to DB. All columns mandatory even if liftover not used:

    CREATE TABLE IF NOT EXISTS "scorefile" (
      "chr_name" INTEGER,
      "chr_position" INTEGER,
      "effect_allele" TEXT,
      "other_allele" TEXT,
      "effect_weight" REAL,
      "effect_type" TEXT,
      "accession" TEXT,
      "qc" INTEGER,
      "lifted_chr" INTEGER,
      "lifted_pos" INTEGER,
      "liftover" INTEGER
    );

    qc and liftover are boolean to note if they pass / fail, and must be nullable
    """
    assert set(df.columns) == {'chr_name', 'chr_position', 'effect_allele', \
                               'other_allele', 'effect_weight', 'effect_type', \
                               'accession', 'qc', 'lifted_chr', 'lifted_pos', \
                               'liftover'}
    nullable_ints = ['liftover', 'qc', 'lifted_chr', 'lifted_pos']
    df[nullable_ints] = df[nullable_ints].astype('Int64')
    df.to_sql('scorefile', conn, index = False)

def main(args = None):
    conn = sqlite3.connect('read_scorefile.db')

    args = parse_args(args)
    accessions = [get_accession(x) for x in args.scorefiles]
    scorefiles, scorefile_summaries = map(list, zip(*[read_scorefile(x) for x in args.scorefiles]))

    if args.liftover:
        builds = [read_build(x) for x in args.scorefiles]
        [check_build(x, y) for x, y in zip(accessions, builds)]
        lifted_dict = {}
        unlifted_dict = {}
        for score_dict, score_build, accession in zip(scorefiles, builds, accessions):
            scorefile = score_dict.get(accession)
            lifted, unlifted = liftover(accession, scorefile, score_build, args.target_build, args.min_lift)

            lifted_dict[accession] = lifted
            unlifted_dict[accession] = unlifted

        log = liftover_summary(lifted_dict, unlifted_dict, scorefile_summaries)
        write_pickle({k: format_lifted(v) for k,v in lifted_dict.items()}, args.outfile)
    else:
        log = (pd.concat(scorefile_summaries)
            .assign(liftover = None, lifted_chr = None, lifted_pos = None))
        write_pickle(reduce(lambda x, y: { **x, **y }, scorefiles), args.outfile)

    write_log(log, conn)

if __name__ == "__main__":
    sys.exit(main())
