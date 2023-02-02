#!/usr/bin/env python3

import argparse
from functools import reduce
import operator


def _parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Relabel the column values in one file based on a pair of columns in another",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-m", "--maps", help='mapping filenames', dest='map_files', nargs='+')
    parser.add_argument("--col_from", help='column to change FROM', dest='col_from')
    parser.add_argument("--col_to", help='column to change TO', dest='col_to')
    parser.add_argument("--target_file", help='target file', dest='target_file')
    parser.add_argument("--target_col", help='target column to revalue', dest='target_col')

    parser.add_argument("--out", help='output filename', dest='out_file')

    return parser.parse_args(args)


def read_map(path, col_from, col_to):
    # Read the mapping file
    with open(path, 'r') as in_map:
        h = in_map.readline().strip().split()
        i_from = h.index(col_from)
        i_to = h.index(col_to)

        mapping = {}
        for line in in_map:
            line = line.strip().split()
            mapping[line[i_from]] = line[i_to]
    return mapping


def relabel_IDs():
    args = _parse_args()

    map_list = [read_map(x, args.col_from, args.col_to) for x in args.map_files]
    mapping = reduce(operator.ior, map_list, {})  # merge dicts quickly, ior is equivalent to | operator

    # Read, relabel and output file
    with open(args.out_file, 'w') as outf:
        with open(args.target_file, 'r') as in_target:
            h = in_target.readline().strip().split()
            i_target_col = h.index(args.target_col)
            outf.write('\t'.join(h) + '\n')

            # relabel lines
            for line in in_target:
                line = line.strip().split()
                line[i_target_col] = mapping[line[i_target_col]]  # revalue column
                outf.write('\t'.join(line) + '\n')


if __name__ == "__main__":
    relabel_IDs()
