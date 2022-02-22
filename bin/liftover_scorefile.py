#!/usr/bin/env python3

import argparse
import sys
import csv
import os.path
import sqlite3
import pickle
from pyliftover import LiftOver

def parse_args(args=None):
    parser = argparse.ArgumentParser(description='Read and format scoring files')
    parser.add_argument('-s','--scorefiles', dest = 'scorefiles', nargs='+',
                        help='<Required> Scorefile path (wildcard * is OK)', required=True)
    parser.add_argument('--scorefile_build', dest = 'scorefile_build',
                        help='<Required> Scorefile build [hg19, hg38]', required=True)
    parser.add_argument('--target_build', dest = 'target_build',
                        help='<Required> Target genome build [hg19, hg38]', required=True)
    parser.add_argument('--min_liftover', dest = 'min_liftover', default = 0.95, type = float,
                        help='<Required> Minimum proportion of variants to liftover [0-1]', required=True)
    return parser.parse_args()

def id_to_coord(line):
    ''' Extract genomic coordinates from ID field (chr:pos:ref:alt) '''

    coords = line.get('ID').split(':')[:2]
    chrom = '{}{}'.format('chr', coords[0])
    pos = int(coords[1]) - 1 # VCF is 1-indexed, liftOver is 0-indexed
    return chrom, pos

def coord_to_id(converted, line):
    alleles = line.get('ID').split(':')[2:]
    chrom = converted[0][3:] # skip 'chr'
    pos = converted[1]
    line['ID'] = ':'.join(map(str, [chrom, pos] + alleles))
    return line

def convert_coordinate(lo, chrom, pos):
    return lo.convert_coordinate(chrom, pos)

def liftover(lo, line):
    chrom, pos = id_to_coord(line)
    converted = convert_coordinate(lo, chrom, pos)

    if converted:
        return coord_to_id(converted[0], line) # first match
    else:
        return None

def liftover_scorefile(inpath, from_build, to_build, min_lift):
    lo = LiftOver(from_build, to_build)

    stats = { 'scorefile': os.path.basename(inpath), 'scorefile_variants': 0, 'mapped_variants': 0, 'unmapped_variants': 0, 'min_liftover': min_lift  }
    mapped_lst = []
    unmapped = { 'ID': [] }

    with open(inpath) as f:
        tsv = csv.DictReader(f, delimiter = "\t")

        for line in tsv:
            stats['scorefile_variants'] += 1
            mapped = liftover(lo, line)

            if mapped is not None:
                mapped_lst.append(mapped)
                stats['mapped_variants'] += 1
            else:
                unmapped['ID'].append(line.get('ID'))
                stats['unmapped_variants'] +=1

    stats['mapped'] = stats['mapped_variants'] / stats['scorefile_variants']

    liftover_err = ''' ERROR: liftOver mapped coordinates badly
    Scorefile: {scorefile_path}
    Scorefile build: {scorefile_build}
    Target genome build: {target_build}
    Scorefile variants: {scorefile_variants}
    Mapped: {mapped}
    Unmapped: {unmapped}
    Are you sure you specified the correct scorefile build?
    --min_liftover defaults to 0.95
    '''
    assert stats['mapped'] > stats['min_liftover'], liftover_err.format(scorefile_path = os.path.basename(inpath), \
        scorefile_build = from_build, target_build = to_build, \
        scorefile_variants = stats['scorefile_variants'], mapped = stats['mapped_variants'], \
        unmapped = stats['unmapped_variants'])
    write_stats(stats)

    fout = '{}.{}'.format(os.path.basename(inpath), 'lifted')
    write_lifted(fout, mapped_lst)


def write_stats(stats):
    con = sqlite3.connect('liftover.db')
    cur = con.cursor()
    cur.execute('''CREATE TABLE IF NOT EXISTS liftover
        (scorefile text, scorefile_variants real, mapped_variants real, unmapped_variants real, min_liftover real, mapped real)
    ''')

    cur.execute("INSERT INTO liftover VALUES (?,?,?,?,?,?)", [*stats.values()])

    con.commit()
    con.close()

def write_lifted(path, mapped_lst):
    with open(path, 'w', newline='') as lifted:
        writer = csv.DictWriter(lifted, delimiter = "\t", fieldnames= mapped_lst[0].keys())
        writer.writeheader()
        [writer.writerow(x) for x in mapped_lst]

def main(args = None):
    args = parse_args(args)
    [liftover_scorefile(x, args.scorefile_build, args.target_build, args.min_liftover) for x in args.scorefiles]

if __name__ == "__main__":
    sys.exit(main())
