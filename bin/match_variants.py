#!/usr/bin/env python3

import pandas as pd
import pickle
import sqlite3
from functools import reduce

def get_matched(con):
    cur = con.cursor()

    # matched variants: EA = REF and OA = ALT
    cur.execute('''
        CREATE TABLE matched AS
        SELECT
            scorefile.chrom || ':' || scorefile.pos || ':' || effect || ':' || other AS id,
            scorefile.chrom,
            scorefile.pos,
            scorefile.effect,
            scorefile.other,
            scorefile.weight,
            scorefile.type
        FROM
            scorefile
        INNER JOIN target ON scorefile.chrom = target.'#CHROM' AND
            scorefile.pos = target.pos AND
            scorefile.effect = target.'REF' AND
            scorefile.other = target.ALT
    ''')

    # matched variants: EA = ALT and OA = REF
    cur.execute('''
        INSERT INTO matched
        SELECT
            scorefile.chrom || ':' || scorefile.pos || ':' || other || ':' || effect AS id,
            scorefile.chrom,
            scorefile.pos,
            scorefile.effect,
            scorefile.other,
            scorefile.weight,
            scorefile.type
        FROM
            scorefile
        INNER JOIN target ON scorefile.chrom = target.'#CHROM' AND
            scorefile.pos = target.pos AND
            scorefile.effect = target.ALT AND
            scorefile.other = target.'REF'
    ''')

    con.commit()
    cur.close()

def get_unmatched(con):
    cur = con.cursor()

    cur.execute('''
    CREATE TABLE unmatched AS
    SELECT
        scorefile.chrom,
        scorefile.pos,
        scorefile.effect,
        scorefile.other,
        scorefile.weight,
        scorefile.type
    FROM
        scorefile
    INNER JOIN
    -- subquery: exclude matched variant positions
        (SELECT scorefile.chrom, scorefile.pos FROM scorefile
            EXCEPT
        SELECT matched.chrom, matched.pos FROM matched)
    USING (chrom, pos)
    ''')

    con.commit()
    cur.close()

def get_flipped(con):
    cur = con.cursor()

    cur.execute('''
        CREATE VIEW flipped AS
        SELECT
            chrom,
            pos,
            effect,
            other,
            weight,
            type
        FROM
            -- subquery: get a table with flipped effect alleles
            (SELECT
            chrom,
            pos,
            complement AS effect,
            weight,
            type
            FROM unmatched
            INNER JOIN flip
            ON unmatched.effect = flip.nucleotide)
        INNER JOIN
            -- subquery: get a table with flipped other alleles too
            (SELECT
            chrom,
            pos,
            complement AS other
            FROM unmatched
            INNER JOIN flip
            ON unmatched.other = flip.nucleotide)
        USING (chrom, pos);
    ''')

    cur.execute('''
        INSERT INTO matched
         -- match by EA = REF and OA = ALT
        SELECT
            flipped.chrom || ':' || flipped.pos || ':' || flipped.effect || ':' || flipped.other AS id,
            flipped.chrom,
            flipped.pos,
            flipped.effect,
            flipped.other,
            flipped.weight,
            flipped.type
        FROM
            flipped
        INNER JOIN
            target
        ON
            flipped.chrom = target.'#CHROM' AND
            flipped.pos = target.pos AND
            flipped.effect = target.'REF' AND
            flipped.other = target.ALT
        UNION ALL
        -- match by EA = ALT and OA = REF
        SELECT
            flipped.chrom || ':' || flipped.pos || ':' || flipped.other || ':' || flipped.effect AS id,
            flipped.chrom,
            flipped.pos,
            flipped.effect,
            flipped.other,
            flipped.weight,
            flipped.type
        FROM
            flipped
        INNER JOIN
            target
        ON
            flipped.chrom = target.'#CHROM' AND
            flipped.pos = target.pos AND
            flipped.effect = target.ALT AND
            flipped.other = target.'REF';
    ''')

    con.commit()
    cur.close()

def import_scorefile(conn, df, col_names):
    # easier to query short names, I am lazy
    df.rename(columns = col_names, inplace = True)

    # index manually
    df.to_sql('scorefile', conn, index = False)

    cur = conn.cursor()

    cur.execute('''
        CREATE INDEX idx_scorefile on scorefile (pos, chrom);
    ''')

    conn.commit()
    cur.close()

def import_target(conn, path):
    df = pd.read_csv(path, sep = "\t")

    # index manually
    df.to_sql('target', conn, index = False)

    cur = conn.cursor()

    cur.execute('''
        CREATE INDEX idx_target ON target (pos, '#CHROM')
    ''')

    cur.execute('''
        CREATE TABLE flip (
            nucleotide TEXT NOT NULL,
            complement TEXT NOT NULL
        )
    ''')

    cur.execute('''
        INSERT INTO flip (nucleotide, complement)
        VALUES
            ('A', 'T'),
            ('T', 'A'),
            ('C', 'G'),
            ('G', 'C')
    ''')

    conn.commit()
    cur.close()

def teardown_tables(conn):
    # drop analysis tables, get ready for a new scorefile
    cur = conn.cursor()

    cur.execute('''
        DROP TABLE scorefile
    ''')
    cur.execute('''
        DROP TABLE matched
    ''')
    cur.execute('''
        DROP TABLE unmatched
    ''')
    cur.execute('''
        DROP VIEW flipped
    ''')

    conn.commit()
    cur.close()

def read_scorefiles(pkl):
    jar = open(pkl, "rb")
    scorefiles = pickle.load(jar)
    return scorefiles

def merge_scorefiles(x, y):
    return x.merge(y, on = ['id', 'effect_allele', 'effect_type'], how = 'outer')

def split_effect_type(df):
    # split df by effect type (additive, dominant, or recessive) into a dict of
    # dfs
    grouped = df.groupby('effect_type')
    return { k: grouped.get_group(k).drop('effect_type', axis = 1 ) for k, v in
        grouped.groups.items() }

def match_variants(conn, scorefile, accession):
    # shorten column names for lazy SQL lookups
    col_names = {'chr_name': 'chrom', 'chr_position': 'pos', 'effect_allele':
    'effect', 'other_allele': 'other', 'effect_weight': 'weight', 'effect_type':
    'type'}

    # matching stuff quickly with tuned sql queries ----------------------------
    import_scorefile(conn, scorefile, col_names)
    get_matched(conn) # simple matching, EA = REF or EA = ALT
    get_unmatched(conn)
    get_flipped(conn) # flip only unmatched, try matching EA = REF or EA = ALT

    # extract results ----------------------------------------------------------
    # read matches back into pandas df, return column names back to original
    # set effect weight to accession to prepare for merging
    matched = (
        pd.read_sql('SELECT * from matched', conn)
        .rename(columns = {v: k for k, v in col_names.items()})
        .loc[:, ['id', 'effect_allele', 'effect_type', 'effect_weight']]
        .rename(columns = {'effect_weight': accession})
        .sort_values(by=['id'])
        )

    # reporting and cleanup ----------------------------------------------------
    make_report(conn, accession)
    teardown_tables(conn)

    return matched

def make_report(conn, accession):
    cur = conn.cursor()
    queries = ["SELECT COUNT(pos) AS flip_matched FROM flipped EXCEPT SELECT pos FROM matched", \
               "SELECT COUNT(pos) AS matched FROM matched EXCEPT SELECT pos FROM flipped", \
               "SELECT COUNT(pos) AS scorefile_variants FROM scorefile", \
               "SELECT COUNT(POS) AS target_variants FROM target"]
    result = reduce(lambda x, y: x.combine_first(y), [pd.read_sql(x, conn) for x in queries])
    result["accession"] = accession
    result.to_sql("report", conn, if_exists = "append", index = False)

def unduplicate_variants(df):
    # when merging a lot of scoring files, sometimes a variant might be duplicated
    # this can happen when the effect allele differs at the same position, e.g.:
    #     - chr1: chr2:20003:A:C A 0.3 NA
    #     - chr1: chr2:20003:A:C C NA 0.7
    # where the last two columns represent different scores.  plink demands
    # unique identifiers! so need to split, score, and sum later

    # .duplicated() marks first duplicate element as True
    # cats, cats, dogs -> False, True, False
    ea_ref = ~df.duplicated(subset=['id'], keep='first')
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

conn = sqlite3.connect('test.db')
import_target(conn, "cineca_synthetic_subset.combined")

unpickled_scorefiles = read_scorefiles("scorefiles.pkl") # { accession: df }
matched_scorefiles = [match_variants(conn, v, k) for k, v in unpickled_scorefiles.items()]
merged_scorefile = reduce(lambda x, y: x.merge(y, on = ['id', 'effect_allele',
    'effect_type'], how = 'outer'), matched_scorefiles)
split_effects = split_effect_type(merged_scorefile)
unduplicated = { k: unduplicate_variants(v) for k, v in split_effects.items() }
[write_scorefiles(k, v) for k, v in unduplicated.items() ]
pd.read_sql("select * from report", conn).to_csv("report.csv", index = False)

# to do: argparse
# to do: double check ambiguous alleles??
