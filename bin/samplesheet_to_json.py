#!/usr/bin/env python3

import sys
import argparse
import os.path
import pandas as pd
import numpy as np

def parse_args(args=None):
    Description = "Convert pgscatalog/pgsc_calc samplesheet file to JSON and check its contents."
    Epilog = "Example usage: python samplesheet_to_json.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)

def check_samplesheet(file_in, file_out):
    """
    This function checks that the samplesheet follows the following structure:
    sample,vcf_path,bfile_path,chrom,chunk
    cineca_synthetic_subset,cineca_synthetic_subset.vcf.gz,,22,
    """
    csv = pd.read_csv(file_in, sep = ',', header = 0)
    colnames = {'sample', 'vcf_path', 'bfile_path', 'pfile_path', 'chrom'}
    colname_err = "ERROR: Samplesheet has bad column names"
    assert set(csv.columns) == colnames, colname_err

    # basic error checking
    check_paths_exclusive(csv)
    check_chrom(csv)

    # check target genomic data existence
    csv.vcf_path = csv['vcf_path'].apply(check_vcf_paths)
    csv[['bed', 'bim', 'fam']] = csv['bfile_path'].apply(check_bfile_paths).str.split(',', 3, expand = True)
    csv[['pgen', 'psam', 'pvar']] = csv['pfile_path'].apply(check_pfile_paths).str.split(',', 3, expand = True)

    (csv.drop(['bfile_path', 'pfile_path'], axis=1)
     .replace(r'^\s*$', np.nan, regex = True)
     .to_json(file_out, orient = 'records'))

def check_paths_exclusive(df):
    genome_paths = ['vcf_path', 'bfile_path', 'pfile_path']
    genome_df = df[genome_paths].fillna("")
    missing_err = "ERROR: No genome paths specified in a sample"

    assert not (genome_df.applymap(pd.isnull)).all(axis = 1).any(), missing_err

    assert not (genome_df.applymap(len)
     .apply(lambda x: x > 0, axis = 1)
     .agg(sum, axis = 1) > 1
     ).any(), "ERROR: Multiple genome paths set in a sample"

def check_chrom(df):
    sample_group = df.groupby(['sample'])
    chrom_unique_error = "Chromosomes must be unique for each sample: {}"
    chrom_nan_error = "Multiple samples with same label MUST have unique chroms specified: {}"
    for sample, group in sample_group:
        assert len(group['chrom'].unique()) == len(group['chrom']), chrom_unique_error.format(sample)
        if group['chrom'].hasnans:
            assert len(group['chrom']) == 1, chrom_nan_error.format(sample)

def check_vcf_paths(path):
    if pd.isnull(path):
        return path
    else:
        assert path.endswith(".vcf.gz"), "vcf_path is specified but doesn't end with .vcf.gz"
        return path

def check_bfile_paths(path):
    if pd.isnull(path):
        bed = bim = fam = ''
        return ','.join([bed, bim, fam])
    else:
        bim = path + ".bim"
        bed = path + ".bed"
        fam = path + ".fam"
        return ','.join([bim, bed, fam])

def check_pfile_paths(path):
    if pd.isnull(path):
        pgen = psam = pvar = ''
        return ','.join([pgen, psam, pvar])
    else:
        pgen = path + ".pgen"
        psam = path + ".psam"
        pvar = path + ".pvar"
        return ','.join([pgen, psam, pvar])

def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)

if __name__ == "__main__":
    sys.exit(main())
