#!/usr/bin/env python3

import pandas as pd
import argparse
import os.path
import sys
from typing import Dict, List, Tuple, Optional, TextIO
import re
import gzip
import io
import sqlite3
from functools import reduce
import pyliftover
import logging


logger = logging.getLogger(__name__)
log_fmt = "%(name)s: %(asctime)s %(levelname)-8s %(message)s"
logging.basicConfig(level=logging.DEBUG,
                    format=log_fmt,
                    datefmt='%Y-%m-%d %H:%M:%S')


def parse_args(args=None) -> argparse.Namespace:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s', '--scorefiles', dest='scorefiles', nargs='+',
                        help='<Required> Scorefile path (wildcard * is OK)', required=True)
    parser.add_argument('--liftover', dest='liftover',
                        help='<Optional> Convert scoring file variants to target genome build?', action='store_true')
    parser.add_argument('-t', '--target_build', dest='target_build', help='Build of target genome <GRCh37 / GRCh38>',
                        required='--liftover' in sys.argv)
    parser.add_argument('-m', '--min_lift', dest='min_lift',
                        help='<Optional> If liftover, minimum proportion of variants lifted over',
                        default=0.95, type=float)
    parser.add_argument('-o', '--outfile', dest='outfile', required=True,
                        default='scorefiles.pkl',
                        help='<Required> Output path to pickled list of scorefiles, e.g. scorefiles.pkl')
    return parser.parse_args(args)



def set_effect_type(x: pd.DataFrame, path: str) -> pd.DataFrame:
    """ Do error checking and extract effect type from single effect weight scorefile """

    logger.info("Setting effect types {}".format(path))

    mandatory_columns: List[str] = ["chr_name", "chr_position", "effect_allele", "effect_weight"]
    col_error: str = "ERROR: Missing mandatory columns"

    if 'other_allele' in x.columns:
        mandatory_columns.extend(['other_allele'])

    if not {'is_recessive', 'is_dominant'}.issubset(x.columns):
        assert set(mandatory_columns).issubset(x.columns), col_error
        scorefile: pd.DataFrame = (x[mandatory_columns].assign(effect_type='additive'))  # default effect type
    else:
        mandatory_columns.extend(["is_recessive", "is_dominant"])
        assert set(mandatory_columns).issubset(x.columns), col_error

        truth_error = ''' ERROR: Bad scorefile {}
        is_recessive and is_dominant columns are both TRUE for a variant
        These columns are mutually exclusive (both can't be true)
        Both can be FALSE for additive variant scores
        '''
        assert not x[['is_dominant', 'is_recessive']].all(axis=1).any(), truth_error.format(path)

        scorefile: pd.DataFrame = (
            x[mandatory_columns]
            .assign(additive=lambda x: (x["is_recessive"] == False) & (x["is_dominant"] == False))
            .assign(effect_type=lambda df: df[["is_recessive", "is_dominant", "additive"]].idxmax(1))
            .drop(["is_recessive", "is_dominant", "additive"], axis=1)
        )

    # if there are multiple effect weights per position, remove the score (delete all rows)
    # only works with single effect weight scoring files
    if not ((scorefile[['chr_name', 'chr_position', 'effect_weight']]
                     .groupby(['chr_name', 'chr_position'])
                     .count() == 1).all().all()):
        scorefile = scorefile[0:0]
        logger.warning("Multiple effect weights detected for one position, skipping score")

    if 'other_allele' not in scorefile:
        return scorefile.assign(other_allele=None)
    else:
        return scorefile


def quality_control(accession: str, df: pd.DataFrame) -> pd.DataFrame:
    """ Do basic error checking and quality control on scorefile variants """

    logger.info("Error checking and quality control {}".format(accession))

    qc: pd.DataFrame = (
        df.query('effect_allele != "P" | effect_allele != "N"')
        .dropna(subset=['chr_name', 'chr_position', 'effect_weight'])
    )

    drop_multiple_oa(qc)

    unique_err: str = ''' ERROR: Bad scorefile "{}"
    Duplicate variant identifiers in scorefile (chr:pos:effect:other)
    Please use only unique variants and try again!
    '''

    unique_df: pd.Series = qc.groupby(['chr_name', 'chr_position', 'effect_allele', 'other_allele']).size() == 1
    assert unique_df.all(), unique_err.format(accession)

    return qc


def score_summary(raw: Dict[str, pd.DataFrame], qc: Dict[str, pd.DataFrame]) -> pd.DataFrame:
    """ Concatenate and label raw input scores if they pass / fail QC """
    idx: List[str] = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight',
                      'effect_type', 'accession']
    raw_scores: pd.DataFrame = pd.concat([v.assign(accession=k) for k, v in raw.items()])
    qc_scores: pd.DataFrame = pd.concat([v.assign(accession=k) for k, v in qc.items()])
    # outer join to find raw scores missing from QC and then label with fail
    return (qc_scores
            .assign(qc=True)
            .merge(raw_scores, how='outer')
            .fillna(value={'qc': False}))


def drop_multiple_oa(df):
    """ Set alleles to None in hm_inferOtherAllele if they contain multiple alleles

    e.g. A / C / T -> None; A -> A; A / C -> None
    """
    df['other_allele'].replace(regex = '.+\/.+', value = None, inplace = True)


def check_hm_data(df):
    """ Check if scorefile contains harmonised columns. Drop and rename columns if they do. """
    if any([re.match("hm_\w+", x) for x in df.columns]):
        harmonised_colnames =  {'hm_chr': 'chr_name', 'hm_pos': 'chr_position', 'hm_inferOtherAllele': 'other_allele'}
        df.drop(['chr_name', 'chr_position', 'other_allele'], axis = 1, inplace = True, errors = 'ignore')
        df.rename(harmonised_colnames, inplace = True, axis = 1)


def scorefile_dtypes():
    return {'rsID': str, 'chr_name': str, 'chr_position': pd.UInt64Dtype(), 'effect_allele': 'str',
            'effect_weight': float, 'locus_name': str, 'OR': float, 'hm_source': str, 'hm_rsID': str,
            'hm_chr': str, 'hm_pos': pd.UInt64Dtype(), 'hm_inferOtherAllele': str}


def read_scorefile(path: str) -> Tuple[Dict[str, pd.DataFrame], pd.DataFrame]:
    """ Read essential information from a scorefile """

    logging.info("Reading scorefile {}".format(path))

    df: pd.DataFrame = pd.read_table(path, dtype = scorefile_dtypes(), comment="#",
                                     na_values=['None'])
    # None in PGS000041_hmPOS_GRCh37.txt.gz

    check_hm_data(df)


    assert len(df.columns) > 1, "ERROR: scorefile not formatted correctly"
    assert {'chr_name', 'chr_position'}.issubset(df.columns), \
        "ERROR: Need chr_position and chr_name (rsids not supported yet!)"
    assert 'effect_allele' in df, "ERROR: Missing effect allele column"

    # check for a single effect weight column called 'effect_weight'
    columns: List[Optional[re.match]] = [re.search("^effect_weight$", x) for x in df.columns.to_list()]
    columns_suffix: List[Optional[re.match]] = [re.search("^effect_weight_[A-Za-z0-9]+$", x) for x
                                                in df.columns.to_list()]

    if any(col is not None for col in columns):
        # scorefiles with a single effect weight column might have effect types
        accession: str = get_accession(path)
        scorefile: Dict[str, pd.DataFrame] = {accession: set_effect_type(df, path)}
    elif any(col is not None for col in columns_suffix):
        # otherwise effect weights have a suffix e.g. effect_weight_PGS0001
        # need to process these differently
        scorefile: Dict[str, pd.DataFrame] = multi_ew(df)
    else:
        assert 0, "ERROR: Missing valid effect weight columns"

    qc_scorefile: Dict[str, pd.DataFrame] = {k: quality_control(k, v) for k, v in scorefile.items()}

    return qc_scorefile, score_summary(scorefile, qc_scorefile)


def multi_ew(x: pd.DataFrame) -> Dict[str, pd.DataFrame]:
    """ Split a scorefile with multiple effect weights into a dict of dfs """

    logger.info("Processing multiple effect weights")

    # different mandatory columns for multi score (effect weight has a suffix)
    mandatory_columns: List[str] = ["chr_name", "chr_position", "effect_allele", "other_allele"]
    col_error: str = "ERROR: Missing mandatory columns"
    assert set(mandatory_columns).issubset(x.columns), col_error

    ew_cols: List[str] = x.filter(regex="effect_weight_*").columns.to_list()
    accessions: List[str] = [x.split('_')[-1] for x in ew_cols]
    split_scores: List[pd.DataFrame] = [
        (x.filter(items=mandatory_columns + [ew])
         .rename(columns={ew: 'effect_weight'})
         .assign(effect_type='additive')
         )
        for ew in ew_cols]

    return dict(zip(accessions, split_scores))


def parse_lifted_chrom(i: str) -> Optional[int]:
    """ Convert lifted chromosomes to tidy integers

    liftover needs chr suffix for chromosome input (1 -> chr1), and it also
    returns weird chromosomes sometimes (chr22 -> 22_KI270879v1_alt)
    """
    return i.split('_')[0]


def convert_coordinates(df: pd.DataFrame, lo: pyliftover.LiftOver) -> pd.Series:
    """ Convert genomic coordinates to different build """
    chrom: str = 'chr' + str(df['chr_name'])
    pos: int = int(df['chr_position']) - 1  # liftOver is 0 indexed, VCF is 1 indexed
    # converted example: [('chr22', 15460378, '+', 3320966530)] or None
    converted: Optional[List[Tuple[str, int, str, int]]] = lo.convert_coordinate(chrom, pos)

    if converted:
        lifted_chrom: str = parse_lifted_chrom(converted[0][0][3:])  # return first matching liftover
        lifted_pos: int = int(converted[0][1]) + 1  # reverse 0 indexing
        return pd.Series([lifted_chrom, lifted_pos])
    else:
        return pd.Series([None, None])


def liftover(accession: str,
             df: pd.DataFrame,
             from_build: str,
             to_build: str,
             min_lift: float) -> Tuple[pd.DataFrame, pd.DataFrame]:
    """ Update scorefile pd.DataFrame with lifted coordinates """
    build_dict: dict = {'GRCh37': 'hg19', 'GRCh38': 'hg38', 'hg19': 'hg19', 'hg38': 'hg38'}

    if build_dict[from_build] == build_dict[to_build]:
        df[['lifted_chr', 'lifted_pos']] = df[['chr_name', 'chr_position']]
        mapped: pd.DataFrame = df.assign(liftover=None)
        unmapped: pd.DataFrame = df.assign(liftover=None)[0:0]  # just keep col structure

        return mapped, unmapped
    else:
        # chain paths in working directory, staged by nextflow module:
        # hg19ToHg38.over.chain.gz
        # hg38ToHg19.over.chain.gz
        chain_path: str = "{}To{}.over.chain.gz".format(build_dict[from_build], build_dict[to_build].capitalize())
        lo: pyliftover.LiftOver = pyliftover.LiftOver(chain_path)
        df[['lifted_chr', 'lifted_pos']] = df.apply(lambda x: convert_coordinates(x, lo), axis=1)
        mapped: pd.DataFrame = df[~df[['lifted_chr', 'lifted_pos']].isnull().any(axis=1)].assign(liftover=True)
        unmapped: pd.DataFrame = df[df[['lifted_chr', 'lifted_pos']].isnull().any(axis=1)].assign(liftover=False)

        check_liftover({'mapped': mapped, 'unmapped': unmapped}, accession, min_lift)

        return mapped, unmapped


def check_liftover(df_dict: Dict[str, pd.DataFrame], accession: str, min_lift: float) -> None:
    """ Write liftover statistics to a database """
    n_mapped: int = df_dict['mapped'].shape[0]
    n_unmapped: int = df_dict['unmapped'].shape[0]
    total: int = n_mapped + n_unmapped

    err: str = "ERROR: Liftover failed for {}, see --min_lift parameter".format(accession)
    assert n_mapped / total > min_lift, err


def read_build(path: str) -> Optional[str]:
    """ Open scorefiles and automatically handle compressed input """
    try:
        with io.TextIOWrapper(gzip.open(path, 'r')) as f:
            return read_header(f)
    except gzip.BadGzipFile:
        with open(path, 'r') as f:
            return read_header(f)


def read_header(f: TextIO) -> Optional[str]:
    """ Extract genome build of scorefile from PGS Catalog header format """
    build_dict = {'GRCh37': 'hg19', 'GRCh38': 'hg38', 'hg19': 'hg19', 'hg38': 'hg38'}
    for line in f:
        if re.search("^#genome_build", line):
            # get #genome_build=GRCh37 from header
            header = line.replace('\n', '').replace('#', '').split('=')
            # and remap to liftover style
            try:
                return build_dict[header[-1]]
            except KeyError:
                return None  # bad genome build
        elif line[0] != '#':
            # genome build isn't set in header :( stop the loop and cry
            return None


def get_accession(path: str) -> str:
    """ Return the basename of a scoring file without extension """
    return os.path.basename(path).split('.')[0]


def check_build(accession: str, build: Optional[str]) -> None:
    """ Verify a valid build was specified in the scoring file header """
    build_err: str = ''' ERROR: Build not specified in scoring file header
    Please check file: {}
    Valid header examples:
    #genome_build=GRCh37
    #genome_build=GRCh38'''.format(accession)

    assert build is not None, build_err


def write_scorefile(x: Dict[str, pd.DataFrame], outfile: str) -> None:
    """ Combine scorefiles into a big flat TSV """
    logger.info("Writing combined scorefile")
    dfs: List[pd.DataFrame] = []
    [dfs.append(v.assign(accession=k)) for k, v in x.items()]

    # reset column order
    cols: List[str] = ['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type',
                       'accession']
    scorefile = pd.concat(dfs)[cols]

    assert not scorefile.empty, "Empty scorefile output! Problem with input data"
    scorefile.to_csv(outfile, index=False, sep='\t')


def liftover_summary(lifted_dict: Dict[str, pd.DataFrame],
                     unlifted_dict: Dict[str, pd.DataFrame],
                     scorefile_summaries: List[pd.DataFrame]) -> pd.DataFrame:
    """ Flatten pd.DataFrames collections and add liftover status (_chr, _pos).

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

    summary: pd.DataFrame = pd.concat(scorefile_summaries)
    lifted: pd.DataFrame = pd.concat([v.assign(accession=k) for k, v in lifted_dict.items()])
    unlifted: pd.DataFrame = pd.concat([v.assign(accession=k) for k, v in unlifted_dict.items()])
    all_liftover: pd.DataFrame = pd.concat([lifted, unlifted])

    idx: List[str] = ['accession', 'chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight',
                      'effect_type']
    return summary.merge(all_liftover, on=idx)


def format_lifted(lifted: pd.DataFrame) -> pd.DataFrame:
    """ Replace original positions with lifted data for matching variants """
    formatted: pd.DataFrame = (lifted
                               .drop(['chr_position', 'chr_name', 'liftover'], axis=1)
                               .rename(columns={'lifted_chr': 'chr_name', 'lifted_pos': 'chr_position'}))
    return formatted[['chr_name', 'chr_position', 'effect_allele', 'other_allele', 'effect_weight', 'effect_type']]


def write_log(df: pd.DataFrame, conn: sqlite3.Connection) -> None:
    """ Write log to DB. All columns mandatory even if liftover not used:

    CREATE TABLE IF NOT EXISTS "scorefile" (
      "chr_name" TEXT,
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
    assert set(df.columns) == {'chr_name', 'chr_position', 'effect_allele',
                               'other_allele', 'effect_weight', 'effect_type',
                               'accession', 'qc', 'lifted_chr', 'lifted_pos',
                               'liftover'}
    nullable_ints: List[str] = ['liftover', 'qc', 'lifted_pos']
    df[nullable_ints] = df[nullable_ints].astype('Int64')
    df.to_sql('scorefile', conn, index=False)


def main(args=None):
    conn: sqlite3.connect = sqlite3.connect('read_scorefile.db')

    args: argparse.Namespace = parse_args(args)
    accessions: List[str] = [get_accession(x) for x in args.scorefiles]

    scorefiles: List[Dict[str, pd.DataFrame]]
    scorefile_summaries: List[pd.DataFrame]
    scorefiles, scorefile_summaries = map(list, zip(*[read_scorefile(x) for x in args.scorefiles]))

    if args.liftover:
        logger.info("LiftOver requested")
        builds: List[str] = [read_build(x) for x in args.scorefiles]
        [check_build(x, y) for x, y in zip(accessions, builds)]
        lifted_dict: dict = {}
        unlifted_dict: dict = {}
        for score_dict, score_build, accession in zip(scorefiles, builds, accessions):
            scorefile: pd.DataFrame = score_dict[accession]
            lifted: pd.DataFrame
            unlifted: pd.DataFrame
            lifted, unlifted = liftover(accession, scorefile, score_build, args.target_build, args.min_lift)

            lifted_dict[accession] = lifted
            unlifted_dict[accession] = unlifted

        log: pd.DataFrame = liftover_summary(lifted_dict, unlifted_dict, scorefile_summaries)
        write_scorefile({k: format_lifted(v) for k, v in lifted_dict.items()}, args.outfile)
    else:
        logger.info("LiftOver not requested")
        log: pd.DataFrame = (pd.concat(scorefile_summaries)
                             .assign(liftover=None, lifted_chr=None, lifted_pos=None))
        write_scorefile(reduce(lambda x, y: {**x, **y}, scorefiles), args.outfile)

    write_log(log, conn)


if __name__ == "__main__":
    sys.exit(main())
