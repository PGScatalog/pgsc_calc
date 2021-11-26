#!/usr/bin/env python3

import argparse
import sqlite3
from pathlib import Path
import subprocess
import pandas as pd
import sys

parser = argparse.ArgumentParser(description='Match variants from a scoring file to target genomic data')
parser.add_argument('--min_overlap', dest='min_overlap', required=True, type = float)
parser.add_argument('--scorefile', dest='scorefile', required=True)
parser.add_argument('--target', dest='target', required=True)
parser.add_argument('--db', dest='db', required=True)
parser.add_argument('--out', dest='outfile', required=True)
args = parser.parse_args()

def connect_db(db_path):
    db = Path(db_path).resolve()
    con = sqlite3.connect(db)
    return con

def make_tables(con):
    cur = con.cursor()

    # Create table
    cur.execute('''
        CREATE TABLE scorefile(
            "chrom" TEXT,
            "pos" TEXT,
            "effect" TEXT,
            "other" TEXT,
            "weight" TEXT)
    ''')

    cur.execute('''
        CREATE TABLE flip (
            nucleotide TEXT NOT NULL,
            complement TEXT NOT NULL
        )
    ''')

    con.commit()
    cur.close()

def import_tables(con, db_path, scorefile_path, target_path):
    scorefile = Path(scorefile_path).resolve()
    target = Path(target_path).resolve()
    db = Path(db_path).resolve()
    cur = con.cursor()

    # import with sqlite's native .import (much faster than python loop)
    subprocess.run(['sqlite3',
                         str(db),
                         '-cmd',
                         '.mode tabs',
                         '.import ' + str(scorefile).replace('\\','\\\\')
                                 +' scorefile'])

    subprocess.run(['sqlite3',
                         str(db),
                         '-cmd',
                         '.mode tabs',
                         '.import ' + str(target).replace('\\','\\\\')
                                 +' target'])

    cur.execute('''
        INSERT INTO flip (nucleotide, complement)
        VALUES
            ('A', 'T'),
            ('T', 'A'),
            ('C', 'G'),
            ('G', 'C')
    ''')

    cur.execute('''
        CREATE INDEX idx_scorefile on scorefile (chrom, pos)
    ''')

    cur.execute('''
        CREATE INDEX idx_target ON target ('#CHROM', pos)
    ''')

    con.commit()
    cur.close()


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
            scorefile.weight
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
            scorefile.weight
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
        scorefile.weight
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
            weight
        FROM
            -- subquery: get a table with flipped effect alleles
            (SELECT
            chrom,
            pos,
            complement AS effect,
            weight
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
            flipped.weight
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
            flipped.weight
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

def export_tables(con):
    query = """
    SELECT
        id,
        effect,
        weight
    FROM
        (SELECT
            id,
            chrom,
            pos,
            effect,
            weight
        FROM matched
        ORDER BY chrom, pos);
    """

    return pd.read_sql_query(query,con)

def report(con, df, args):
    # these files can be big, wc is quick
    lines_target = subprocess.run(["wc", "-l", args.target], stdout=subprocess.PIPE)
    n_target = int(lines_target.stdout.decode("utf-8").split()[0])

    lines_scorefile =subprocess.run(["wc", "-l", args.scorefile], stdout=subprocess.PIPE)
    n_scorefile = int(lines_scorefile.stdout.decode("utf-8").split()[0])

    n_matched = len(df.index)
    perc_matched = (n_matched / n_scorefile) * 100

    # check overlap and exit with error if required
    if (perc_matched < args.min_overlap * 100):
        print("""
        ERROR: Your target data seem to overlap poorly with the scoring file
        ERROR: Minimum overlap set to {}%
        ERROR: Only {}% variants matched
        """.format(args.min_overlap * 100, round(perc_matched, 2)))
        sys.exit(1)

    # otherwise write a log
    f = open("match.log", "w")
    f.write("match_variants.py log\n")
    f.write("Percent matched variants: {}%\n".format(round(perc_matched, 2)))
    f.write("Total matched variants: {}\n".format(n_matched))
    f.write("Total variants in scorefile: {}\n".format(n_scorefile))
    f.write("Total variants in target data: {}\n".format(n_target))
    f.write("Minimum overlap: {}%".format(args.min_overlap * 100))
    f.close()

def match_variants(args):
    con = connect_db(args.db)
    make_tables(con)
    import_tables(con, args.db, args.scorefile, args.target)
    get_matched(con)
    get_unmatched(con)
    get_flipped(con)
    df = export_tables(con)
    report(con, df, args)
    df.to_csv(args.outfile, sep = "\t", index = False)
    con.close()

if __name__ == "__main__":
    match_variants(args)
