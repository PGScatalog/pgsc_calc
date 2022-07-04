#!/usr/bin/env python3

import polars as pl
import argparse
import sys
import glob
from typing import List, Dict, Union

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-d', '--dataset', dest='dataset', required=True,
                        help='<Required> Label for target genomic dataset (e.g. "-d thousand_genomes")')
    parser.add_argument('-s', '--scorefiles', dest='scorefile', required=True,
                        help='<Required> Combined scorefile path (output of read_scorefiles.py)')
    parser.add_argument('-t', '--target', dest='target', required=True,
                        help='<Required> A table of target genomic variants (.bim format)')
    parser.add_argument('--split', dest='split', default=False, action='store_true',
                        help='<Required> Split scorefile per chromosome?')
    parser.add_argument('-n', '--n_threads', dest='n_threads', default = 1, type=int,
                        help='<Required> Number of threads used to match (default = 1)')
    parser.add_argument('--format', required = True, dest='plink_format', help='<Required> bim or pvar?')
    parser.add_argument('--db', dest='db', required = True, help='<Required> path to database')
    parser.add_argument('-m', '--min_overlap', dest='min_overlap', required=True,
                        type=float, help='<Required> Minimum proportion of variants to match before error')
    parser.add_argument('--keep_ambiguous', dest='remove_ambiguous', action='store_false',
                        help='Flag to force the program to keep variants with ambiguous alleles, (e.g. A/T and G/C '
                             'SNPs), which are normally excluded (default: false). In this case the program proceeds assuming that the '
                             'genotype data is on the same strand as the GWAS whose summary statistics were used to '
                             'construct the score.'),
    parser.add_argument('--keep_multiallelic', dest='remove_multiallelic', action='store_false',
                        help='Flag to allow matching to multiallelic variants (default: false).')
    return parser.parse_args(args)


def read_pvarcolumns(path: str) -> List[str]:
    """Get the column names from the pvar file (not constrained like bim, especially when converted from VCF)"""
    f_pvar: TextIO = open(path, 'rt')
    line: str = '#'
    header: List[str] = []
    while line.startswith('#'):
        line: str = f_pvar.readline()
        if line.startswith('#CHROM'):
            header = line.strip().split('\t')
    f_pvar.close()
    return header


def read_target(path: str, plink_format: str, remove_multiallelic: bool, n_threads: int) -> pl.DataFrame:
    """Complementing alleles with a pile of regexes seems weird, but polars string
    functions are limited (i.e. no str.translate). Applying a python complement
    function would be very slow compared to this, unless I develop a function
    in rust. I don't know rust, and I stole the regex idea from Scott.
    """
    if plink_format == 'bim':
        # set chr_name to be str, fixes vstacking problem with inferred dtypes
        # ( chr1 + chr2 + chrX = boom )
        x: pl.DataFrame = pl.read_csv(path, sep='\t', has_header=False, n_threads = n_threads,
                                      dtype = {'column_1': str})
        x.columns = ['#CHROM', 'ID', 'CM', 'POS', 'REF', 'ALT']
        x = x[['#CHROM', 'POS', 'ID', 'REF', 'ALT']]  # subset to matching columns
    else:
        # plink2 pvar may have VCF comments in header starting ##
        x: pl.DataFrame = pl.read_csv(path, sep='\t', has_header=False, comment_char='#',
                                      dtype = {'column_1': str}, n_threads = n_threads)

        # read pvar header
        x.columns = read_pvarcolumns(glob.glob(path)[0])  # guess from the first file
        x = x[['#CHROM', 'POS', 'ID', 'REF', 'ALT']]  # subset to matching columns

        # Handle multi-allelic variants
        is_ma: pl.Series = x['ALT'].str.contains(',')  # plink2 pvar multi-alleles are comma-separated
        if is_ma.sum() > 0:
            if remove_multiallelic:
                print('Dropping Multiallelic variants')
                x = x[~is_ma]
            else:
                x.replace('ALT', x['ALT'].str.split(by=','))  # turn ALT to list of variants
                x = x.explode('ALT')  # expand the DF to have all the variants in different rows

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


def read_scorefile(path: str) -> pl.DataFrame:
    scorefile: pl.DataFrame = pl.read_csv(path, sep='\t', dtype = {'chr_name': str})

    assert all((scorefile.groupby(['accession', 'chr_name', 'chr_position', 'effect_allele'])
               .count()['count']) == 1), "Multiple effect weights per variant per accession!"

    return scorefile.with_columns([
        pl.col("effect_allele").cast(pl.Categorical),
        pl.col("other_allele").cast(pl.Categorical),
        pl.col("effect_type").cast(pl.Categorical),
        pl.col("accession").cast(pl.Categorical)
    ])


def match_variants(scorefile: pl.DataFrame,
                   target: pl.DataFrame,
                   EA: str,
                   OA: str,
                   match_type: str) -> pl.DataFrame:
    colnames: List[str] = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type',
                           'accession', 'ID', 'REF', 'ALT', 'REF_FLIP', 'ALT_FLIP', 'match_type']

    if OA:
        matches: pl.DataFrame = scorefile.join(target,
                                               left_on=['chr_name', 'chr_position', 'effect_allele', 'other_allele'],
                                               right_on=['#CHROM', 'POS', EA, OA], how='inner').with_columns([
            pl.col("*"),
            pl.col("effect_allele").alias(EA),  # copy the column that's dropped by join
            pl.col("other_allele").alias(OA),
            pl.lit(match_type).alias("match_type")
        ])
        # join removes matching key, reorder columns for vertical stacking (pl.concat)
        # collecting is needed for reordering columns
    else:
        matches: pl.DataFrame = scorefile.join(target,
                                                       left_on=['chr_name', 'chr_position', 'effect_allele'],
                                                       right_on=['#CHROM', 'POS', EA], how='inner').with_columns([
                    pl.col("*"),
                    pl.col("effect_allele").alias(EA),  # copy the column that's dropped by join
                    pl.lit(match_type).alias("match_type")
                ])

    return matches[colnames]


def get_all_matches(target: pl.DataFrame, scorefile: pl.DataFrame, remove_ambig: bool) -> pl.DataFrame:
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

    If other_allele is missing, match only using effect_allele using the same process
    """

    scorefile_oa = scorefile.filter(pl.col("other_allele") != None)
    scorefile_no_oa = scorefile.filter(pl.col("other_allele") == None)

    matches: Dict[str, pl.DataFrame] = {}

    if scorefile_oa:
        matches['refalt'] = match_variants(scorefile, target, EA='REF', OA='ALT', match_type="refalt")
        matches['altref'] = match_variants(scorefile, target, EA='ALT', OA='REF', match_type="altref")
        matches['refalt_flip'] = match_variants(scorefile, target, EA='REF_FLIP', OA='ALT_FLIP', match_type="refalt_flip")
        matches['altref_flip'] = match_variants(scorefile, target, EA='ALT_FLIP', OA='REF_FLIP', match_type="altref_flip")

    if scorefile_no_oa:
        matches['no_oa_ref'] = match_variants(scorefile_no_oa, target, EA='REF', OA=None, match_type="no_oa_ref")
        matches['no_oa_alt'] = match_variants(scorefile_no_oa, target, EA='ALT', OA=None, match_type="no_oa_alt")
        matches['no_oa_ref_flip'] = match_variants(scorefile_no_oa, target, EA='REF_FLIP', OA=None, match_type="no_oa_ref_flip")
        matches['no_oa_alt_flip'] = match_variants(scorefile_no_oa, target, EA='ALT_FLIP', OA=None, match_type="no_oa_alt_flip")

    ambig_labelled: pl.DataFrame = label_biallelic_ambiguous(pl.concat(list(matches.values())))

    # no. of matches should never be more than the no. of variants in scorefile
    input_count = scorefile.groupby(['accession']).count().sort('accession')
    match_count = ambig_labelled.groupby(['accession']).count().sort('accession')
    assert all(input_count['count'] >= match_count['count'])

    if remove_ambig:
        print('Removing Ambiguous Matches')
        return ambig_labelled.filter(pl.col("ambiguous") == False)
    else:
        # pick the best possible match from the ambiguous matches
        # EA = REF and OA = ALT or EA = REF and OA = None
        ambig: pl.DataFrame = ambig_labelled.filter((pl.col("ambiguous") == True) & \
                                                    (pl.col("match_type") == "refalt") |
                                                    (pl.col("ambiguous") == True) & \
                                                    (pl.col("match_type") == "no_oa_ref"))
        unambig: pl.DataFrame = ambig_labelled.filter(pl.col("ambiguous") == False)
        return pl.concat([ambig, unambig])

def get_distinct_weights(df: pl.DataFrame) -> pl.DataFrame:
    """ Get a single effect weight for each matched variant per accession """
    count: pl.DataFrame = df.groupby(['accession', 'chr_name', 'chr_position', 'effect_allele']).count()
    singletons: pl.DataFrame = (count.filter(pl.col('count') == 1)[:,"accession":"effect_allele"]
            .join(df, on = ['accession', 'chr_name', 'chr_position', 'effect_allele'], how = 'left'))

    # TODO: something more complex than .unique()?
    # prioritise unambiguous -> ref -> alt -> ref_flip -> alt_flip
    dups: pl.DataFrame = (count.filter(pl.col('count') > 1)[:,"accession":"effect_allele"]
            .join(df, on = ['accession', 'chr_name', 'chr_position', 'effect_allele'], how = 'left')
            .unique(subset = ['accession', 'chr_name', 'chr_position', 'effect_allele']))
    distinct: pl.DataFrame = pl.concat([singletons, dups])

    assert all((distinct.groupby(['accession', 'chr_name', 'chr_position', 'effect_allele'])
                .count()['count']) == 1), "Duplicate effect weights for a variant"

    return distinct

def label_biallelic_ambiguous(matches: pl.DataFrame) -> pl.DataFrame:
    # A / T or C / G may match multiple times
    matches = matches.with_columns([
        pl.col(["effect_allele", "other_allele", "REF", "ALT", "REF_FLIP", "ALT_FLIP"]).cast(str),
        pl.lit(True).alias("ambiguous")
    ])

    return get_distinct_weights(matches.with_column(
        pl.when((pl.col("effect_allele") == pl.col("ALT_FLIP")) |
                (pl.col("effect_allele") == pl.col("REF_FLIP")))
            .then(pl.col("ambiguous"))
            .otherwise(False)))


def unduplicate_variants(df: pl.DataFrame) -> List[pl.DataFrame]:
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
    ea_count: pl.DataFrame = (df.select(["ID", "effect_allele"])
        .unique()
        .with_columns([
        pl.col("ID").cumcount().over(["ID"]).alias("cumcount"),
        pl.col("ID").count().over(["ID"]).alias("count")
    ]))

    dup_label: pl.DataFrame = df.join(ea_count, on=["ID", "effect_allele"], how="left")

    # now split the matched variants, and make sure we don't lose any ----------
    n_splits: int = ea_count.select("cumcount").max()[0, 0] + 1  # cumcount = ngroup-1
    df_lst: list = []
    n_var: int = 0

    for i in range(0, n_splits):
        x: pl.DataFrame = dup_label.filter(pl.col("cumcount") == i)
        n_var += x.shape[0]
        df_lst.append(x)

    assert n_var == df.shape[0]

    return df_lst


def format_scorefile(df: pl.DataFrame, split: bool) -> Dict[Union[int, str], pl.DataFrame]:
    """ Format a dataframe to plink2 --score standard

    Minimum example:
    ID | effect_allele | effect_weight

    Multiple scores are OK too:
    ID | effect_allele | weight_1 | ... | weight_n
    """
    if split:
        chroms: List[int] = df["chr_name"].unique().to_list()
        return {x: (df.filter(pl.col("chr_name") == x)
                    .pivot(index=["ID", "effect_allele"], values="effect_weight", columns="accession")
                    .fill_null(pl.lit(0)))
                for x in chroms}
    else:
        return {'false': (df.pivot(index=["ID", "effect_allele"], values="effect_weight", columns="accession")
                          .fill_null(pl.lit(0)))}


def split_effect_type(df: pl.DataFrame) -> Dict[str, pl.DataFrame]:
    effect_types: List[str] = df["effect_type"].unique().to_list()
    return {x: df.filter(pl.col("effect_type") == x) for x in effect_types}


def write_scorefile(effect_type: str, scorefiles: pl.DataFrame, split: bool) -> None:
    """ Write a list of scorefiles with the same effect type """
    fout: str = '{chr}_{et}_{split}.scorefile'

    # each list element contains a dataframe of variants
    # lists are split to ensure variants have unique ID - effect alleles
    for i, scorefile in enumerate(scorefiles):
        df_dict: Dict[Union[int, str], pl.DataFrame] = format_scorefile(scorefile, split)  # may be split by chrom

        for k, v in df_dict.items():
            path: str = fout.format(chr=k, et=effect_type, split=i)
            v.write_csv(path, sep="\t")


def connect_db(path: str) -> str:
    """ Set up sqlite3 connection """
    return 'sqlite://{}'.format(path)


def read_log(conn: str) -> pl.DataFrame:
    """ Read scorefile input log from database """
    query: str = 'SELECT * from scorefile'
    return pl.read_sql(query, conn).with_columns([
        pl.col("chr_name").cast(str),
        pl.col("accession").cast(pl.Categorical),
        pl.col("effect_type").cast(pl.Categorical)
    ])


def join_log(logs: pl.DataFrame, match: pl.DataFrame, lifted: bool) -> pl.DataFrame:
    """ Lifted scorefiles need to match the log using different chr_name chr_pos """

    if lifted:
        return (logs.join(match,
                          left_on=['lifted_chr', 'lifted_pos', 'effect_allele', 'other_allele',
                                   'accession', 'effect_type', 'effect_weight'],
                          right_on=['chr_name', 'chr_position', 'effect_allele', 'other_allele',
                                    'accession', 'effect_type', 'effect_weight'], how='left'))
    else:
        return (logs.join(match,
                          left_on=['chr_name', 'chr_position', 'effect_allele', 'other_allele',
                                   'accession', 'effect_type', 'effect_weight'],
                          right_on=['chr_name', 'chr_position', 'effect_allele', 'other_allele',
                                    'accession', 'effect_type', 'effect_weight'], how='left'))


def update_log(logs: pl.DataFrame,
               matches: pl.DataFrame,
               min_overlap: float,
               dataset: str) -> None:
    """ Read log and update with match data, write to csv """

    match_clean: pl.DataFrame = matches.drop(['REF', 'ALT', 'REF_FLIP', 'ALT_FLIP'])
    unlifted_accessions: pl.DataFrame = logs[['accession', 'liftover']].unique().filter(pl.col('liftover') == None)
    lifted_accessions: pl.DataFrame = logs[['accession', 'liftover']].unique().filter(pl.col('liftover') == 1)
    matches = []

    if lifted_accessions:
        matches.append(join_log(logs, match_clean, lifted = True))

    if unlifted_accessions:
        matches.append(join_log(logs, match_clean, lifted = False))


    match_log: pl.DataFrame = (pl.concat(matches)
                               .with_columns([
                                   pl.col('ambiguous').fill_null(True),
                                   pl.lit(dataset).alias('dataset')
                               ]))

    match_log.write_csv('log.csv') # TODO: sqlite3 database?
    check_match(match_log, min_overlap)


def check_match(match_log: pl.DataFrame, min_overlap: float) -> None:
    """ Explode if matching goes badly """

    fail_rates: pl.DataFrame = (match_log
                                .groupby('accession')
                                .agg([pl.count(), (pl.col('match_type') == None).sum().alias('no_match')])
                                .with_column((pl.col('no_match') / pl.col('count')).alias('fail_rate'))
                                )
    for a, r in zip(fail_rates['accession'].to_list(), fail_rates['fail_rate'].to_list()):
        err: str = "ERROR: Score {} matches your variants badly. Check --min_overlap ({:.2%} min, {:.2%} match)"
        assert r < (1 - min_overlap), err.format(a, min_overlap, 1 - r)


def main(args=None) -> None:
    """ Match variants from scorefiles against target variant information """
    pl.Config.set_global_string_cache()
    args: argparse.Namespace = parse_args(args)

    assert args.plink_format in ['bim', 'pvar'], "--format bim or --format pvar"

    # read inputs --------------------------------------------------------------
    target: pl.DataFrame = read_target(args.target, args.plink_format,
                                       args.remove_multiallelic, args.n_threads)
    scorefile: pl.DataFrame = read_scorefile(args.scorefile)

    # start matching -----------------------------------------------------------
    matches: pl.DataFrame = get_all_matches(target, scorefile, args.remove_ambiguous)

    empty_err: str = ''' ERROR: No target variants match any variants in all scoring files
    This is quite odd!
    Try checking the genome build (see --liftover and --target_build parameters)
    Try imputing your microarray data if it doesn't cover the scoring variants well
    '''
    assert matches.shape[0] > 0, empty_err

    # update logs --------------------------------------------------------------
    conn: str = connect_db(args.db)
    logs: pl.DataFrame = read_log(conn)
    update_log(logs, matches, args.min_overlap, args.dataset)

    # prepare for writing out --------------------------------------------------
    # write one combined scorefile for efficiency, but need extra file for each:
    #     - effect type (e.g. additive, dominant, or recessive)
    #     - duplicated chr:pos:ref:alt ID (with different effect allele)
    ets: Dict[str, pl.DataFrame] = split_effect_type(matches)
    unduplicated: Dict[str, pl.DataFrame] = {k: unduplicate_variants(v) for k, v in ets.items()}
    ea_dict: Dict[str, str] = {'is_dominant': 'dominant', 'is_recessive': 'recessive', 'additive': 'additive'}
    [write_scorefile(ea_dict.get(k), v, args.split) for k, v in unduplicated.items()]


if __name__ == '__main__':
    sys.exit(main())
