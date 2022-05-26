#!/usr/bin/env python3

import polars as pl
import argparse
import sys
import glob

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-d','--dataset', dest = 'dataset', required = True,
                        help='<Required> Label for target genomic dataset (e.g. "-d thousand_genomes")')
    parser.add_argument('-s','--scorefiles', dest = 'scorefile', required = True,
                        help='<Required> Combined scorefile path (output of read_scorefiles.py)')
    parser.add_argument('-t','--target', dest = 'target', required = True,
                        help='<Required> A table of target genomic variants (.bim format)')
    parser.add_argument('--split', dest = 'split', default=False, action='store_true',
                        help='<Required> Split scorefile per chromosome?')
    parser.add_argument('--format', dest = 'plink_format', help='<Required> bim or pvar?')
    parser.add_argument('--db', dest = 'db', help='<Required> path to database')
    parser.add_argument('-m', '--min_overlap', dest='min_overlap', required=True,
                        type = float, help='<Required> Minimum proportion of variants to match before error')
    parser.add_argument('--keep-ambiguous', dest='remove_ambiguous', default=True, action='store_false',
                        help='Flag to force the program to keep variants with ambiguous alleles, (e.g. A/T and G/C '
                             'SNPs), which are normally excluded. In this case the program proceeds assuming that the '
                             'genotype data is on the same strand as the GWAS whose summary statistics were used to '
                             'construct the score.'),
    parser.add_argument('--keep-multiallelic', dest='remove_multiallelic', default=False, action='store_false',
                        help='Flag to preserve multiallelic variants (default: false).')
    return parser.parse_args(args)

def read_pvarcolumns(path):
    """Get the column names from the pvar file (not constrained like bim, especially when converted from VCF)"""
    f_pvar = open(path, 'rt')
    line = '#'
    header = []
    while line.startswith('#'):
        line = f_pvar.readline()
        if line.startswith('#CHROM'):
            header = line.strip().split('\t')
    f_pvar.close()
    return header

def read_target(path, plink_format, remove_multiallelic):
    """Complementing alleles with a pile of regexes seems weird, but polars string
    functions are limited (i.e. no str.translate). Applying a python complement
    function would be very slow compared to this, unless I develop a function
    in rust. I don't know rust, and I stole the regex idea from Scott.
    """
    if plink_format == 'bim':
        x = pl.read_csv(path, sep = '\t', has_header = False)
        x.columns = ['#CHROM', 'ID', 'CM', 'POS', 'REF', 'ALT']
        x = x[['#CHROM', 'POS', 'ID', 'REF', 'ALT']]  # subset to matching columns
    else:
        # plink2 pvar may have VCF comments in header starting ##
        x = pl.read_csv(path, sep = '\t', has_header = False, comment_char='#')

        # read pvar header
        x.columns = read_pvarcolumns(glob.glob(path)[0]) # guess from the first file
        x = x[['#CHROM', 'POS', 'ID', 'REF', 'ALT']]  # subset to matching columns

        # Handle multi-allelic variants
        is_ma = x['ALT'].str.contains(',')  # plink2 pvar multi-alleles are comma-separated
        if is_ma.sum() > 0 and not remove_multiallelic:
            x.replace('ALT', x['ALT'].str.split(by=','))  # turn ALT to list of variants
            x = x.explode('ALT')  # expand the DF to have all the variants in different rows
        elif remove_multiallelic:
            x = x[~is_ma]

    x = x.with_columns([
        (pl.col("REF").str.replace_all("A", "V")
            .str.replace_all("T", "X")
            .str.replace_all("C", "Y")
            .str.replace_all("G", "Z")
            .str.replace_all("V", "T")
            .str.replace_all("X", "A")
            .str.replace_all("Y", "G")
            .str.replace_all("Z", "C"))
            .alias("REF_FLIP"),
        (pl.col("ALT").str.replace_all("A", "V")
            .str.replace_all("T", "X")
            .str.replace_all("C", "Y")
            .str.replace_all("G", "Z")
            .str.replace_all("V", "T")
            .str.replace_all("X", "A")
            .str.replace_all("Y", "G")
            .str.replace_all("Z", "C"))
            .alias("ALT_FLIP")
    ])

    return x.with_columns([
        pl.col("REF").cast(pl.Categorical),
        pl.col("ALT").cast(pl.Categorical),
        pl.col("ALT_FLIP").cast(pl.Categorical),
        pl.col("REF_FLIP").cast(pl.Categorical)])

def read_scorefile(path):
    scorefile = pl.read_csv(path, sep = '\t')
    return scorefile.with_columns([
        pl.col("effect_allele").cast(pl.Categorical),
        pl.col("other_allele").cast(pl.Categorical),
        pl.col("effect_type").cast(pl.Categorical),
        pl.col("accession").cast(pl.Categorical)
   ])

def match_variants(scorefile, target, EA, OA, match_type):
    colnames = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type', 'accession', 'ID', 'REF', 'ALT', 'REF_FLIP', 'ALT_FLIP', 'match_type']

    matches = scorefile.join(target, left_on = ['chr_name', 'chr_position', 'effect_allele', 'other_allele'], right_on = ['#CHROM', 'POS', EA, OA], how = 'inner').with_columns([
        pl.col("*"),
        pl.col("effect_allele").alias(EA), # copy the column that's dropped by join
        pl.col("other_allele").alias(OA),
        pl.lit(match_type).alias("match_type")
        ])
    # join removes matching key, reorder columns for vertical stacking (pl.concat)
    # collecting is needed for reordering columns
    return matches[colnames]

def get_all_matches(target, scorefile, remove_ambig):
    """ Get intersection of variants using four different schemes, optionally
    removing ambiguous variants (default: true)

    scorefile      | target | scorefile   |  target
    effect_allele == REF and other_allele == ALT
    effect_allele == ALT and other_allele == REF
    effect_allele == flip(REF) and other_allele == flip(ALT)
    effect_allele == flip(REF) and oher_allele ==  flip(REF)

    If not removing ambiguous variants, then it's assumed that the genotype data
    is on the same strand as the GWAS whose summary statistics were used to
    construct the score
    """

    refalt = match_variants(scorefile, target, EA = 'REF', OA = 'ALT', match_type = "refalt")
    altref = match_variants(scorefile, target, EA = 'ALT', OA = 'REF', match_type = "altref")
    refalt_flip = match_variants(scorefile, target, EA = 'REF_FLIP', OA = 'ALT_FLIP', match_type = "refalt_flip")
    altref_flip = match_variants(scorefile, target, EA = 'ALT_FLIP', OA = 'REF_FLIP', match_type = "altref_flip")
    ambig_labelled = label_biallelic_ambiguous(pl.concat([refalt, altref, refalt_flip, altref_flip]))

    if remove_ambig:
        return ambig_labelled.filter(pl.col("ambiguous") == False)
    else:
        ambig = ambig_labelled.filter((pl.col("ambiguous") == True) & \
                                      (pl.col("match_type") == "refalt"))
        unambig = ambig_labelled.filter(pl.col("ambiguous") == False)
        return pl.concat([ambig, unambig])

def label_biallelic_ambiguous(matches):
    # A / T or C / G may match multiple times
    matches = matches.with_columns([
        pl.col(["effect_allele", "other_allele", "REF", "ALT", "REF_FLIP", "ALT_FLIP"]).cast(str),
        pl.lit(True).alias("ambiguous")
    ])

    return (matches.with_column(
        pl.when((pl.col("effect_allele") == pl.col("ALT_FLIP")) | \
                (pl.col("effect_allele") == pl.col("REF_FLIP")))
        .then(pl.col("ambiguous"))
        .otherwise(False)))

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
        A list of dataframes, with unique ID - effect allele combinations
    """

    # 1. unique ID - EA is important because normal duplicates are already ----
    #   handled by pivoting, and it's pointless to split them unnecessarily
    # 2. use cumcount to number duplicate IDs
    # 3. join cumcount data on original DF, use this data for splitting
    ea_count = (df.select(["ID", "effect_allele"])
                .unique()
                .with_columns([
                    pl.col("ID").cumcount().over(["ID"]).alias("cumcount"),
                    pl.col("ID").count().over(["ID"]).alias("count")
                ]))

    dup_label = df.join(ea_count, on = ["ID", "effect_allele"], how = "left")

    # now split the matched variants, and make sure we don't lose any ----------
    n_splits = ea_count.select("cumcount").max()[0, 0] + 1 # cumcount = ngroup-1
    df_lst = []
    n_var = 0

    for i in range(0, n_splits):
        x = dup_label.filter(pl.col("cumcount") == i)
        n_var += x.shape[0]
        df_lst.append(x)

    assert n_var == df.shape[0]

    return df_lst

def format_scorefile(df, split):
    """ Format a dataframe to plink2 --score standard

    Minimum example:
    ID | effect_allele | effect_weight

    Multiple scores are OK too:
    ID | effect_allele | weight_1 | ... | weight_n
    """
    if split:
        chroms = df["chr_name"].unique().to_list()
        return { x: (df.filter(pl.col("chr_name") == x)
                     .pivot(index = ["ID", "effect_allele"], values = "effect_weight", columns = "accession")
                     .fill_null(pl.lit(0)))
                 for x in chroms }
    else:
        return { 'false': (df.pivot(index = ["ID", "effect_allele"], values = "effect_weight", columns = "accession")
                           .fill_null(pl.lit(0))) }

def split_effect_type(df):
    effect_types = df["effect_type"].unique().to_list()
    return {x: df.filter(pl.col("effect_type") == x) for x in effect_types}

def write_scorefile(effect_type, scorefiles, split):
    ''' Write a list of scorefiles with the same effect type '''
    fout = '{chr}_{et}_{split}.scorefile'

    # each list element contains a dataframe of variants
    # lists are split to ensure variants have unique ID - effect alleles
    for i, scorefile in enumerate(scorefiles):
        df_dict = format_scorefile(scorefile, split) # may be split by chrom

        for k, v in df_dict.items():
            path = fout.format(chr = k, et = effect_type, split = i)
            v.write_csv(path, sep = "\t")

def connect_db(path):
    ''' Set up sqlite3 connection '''
    return 'sqlite://{}'.format(path)

def read_log(conn):
    ''' Read scorefile input log from database '''
    query = 'SELECT * from scorefile'
    return pl.read_sql(query, conn).with_columns([
        pl.col("accession").cast(pl.Categorical),
        pl.col("effect_type").cast(pl.Categorical)
         ])

def update_log(logs, matches, conn, min_overlap, dataset):
    ''' Read log and update with match data, write to csv '''
    match_clean = matches.drop(['REF', 'ALT', 'REF_FLIP', 'ALT_FLIP'])
    match_log = (logs.join(match_clean, left_on = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'accession', 'effect_type', 'effect_weight'], right_on = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'accession', 'effect_type', 'effect_weight'], how = 'left')
               .with_columns([
                   pl.col('ambiguous').fill_null(True),
                   pl.lit(dataset).alias('dataset')
               ]))

    check_match(match_log, min_overlap)
    match_log.write_csv('log.csv') # TODO: sqlite3 database

def check_match(match_log, min_overlap):
    ''' Explode if matching goes badly '''

    fail_rates = (match_log
     .groupby('accession')
     .agg([ pl.count(), (pl.col('match_type') == None).sum().alias('no_match') ])
     .with_column((pl.col('no_match') / pl.col('count')).alias('fail_rate'))
     )
    for a, r in zip(fail_rates['accession'].to_list(), fail_rates['fail_rate'].to_list()):
        err = "ERROR: Score {} matches your variants badly. Check --min_overlap"
        assert r < (1 - min_overlap), err.format(a)

def main(args = None):
    ''' Match variants from scorefiles against target variant information '''
    pl.Config.set_global_string_cache()
    args = parse_args(args)

    # read inputs --------------------------------------------------------------
    target = read_target(args.target, args.plink_format, args.remove_multiallelic)
    scorefile = read_scorefile(args.scorefile)

    # start matching -----------------------------------------------------------
    matches = get_all_matches(target, scorefile, args.remove_ambiguous)

    empty_err = ''' ERROR: No target variants match any variants in all scoring files
    This is quite odd!
    Try checking the genome build (see --liftover and --target_build parameters)
    Try imputing your microarray data if it doesn't cover the scoring variants well
    '''
    assert matches.shape[0] > 0, empty_err

    # update logs --------------------------------------------------------------
    conn = connect_db(args.db)
    logs = read_log(conn)
    update_log(logs, matches, conn, args.min_overlap, args.dataset)

    # prepare for writing out --------------------------------------------------
    # write one combined scorefile for efficiency, but need extra file for each:
    #     - effect type (e.g. additive, dominant, or recessive)
    #     - duplicated chr:pos:ref:alt ID (with different effect allele)
    ets = split_effect_type(matches)
    unduplicated = { k: unduplicate_variants(v) for k, v in ets.items() }
    ea_dict = { 'is_dominant': 'dominant', 'is_recessive': 'recessive', 'additive': 'additive'}
    [ write_scorefile(ea_dict.get(k), v, args.split) for k, v in unduplicated.items() ]

if __name__ == '__main__':
    sys.exit(main())
