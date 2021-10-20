#!/usr/bin/env python

import os
import sys
import errno
import argparse

def parse_args(args=None):
    Description = "Reformat nf-core/pgscalc samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


def check_samplesheet(file_in, file_out):
    """
    This function checks that the samplesheet follows the following structure:

    sample,path,spec
    dataset1,dataset1.bed,bed
    dataset1,dataset1.bim,bim

    OR:

    sample,path,spec
    chr1,chr1.vcf.gz,vcf
    chr2,chr2.vcf.gz,vcf
    
    TODO: update this
    For an example see:
    https://raw.githubusercontent.com/nf-core/test-datasets/viralrecon/samplesheet/samplesheet_test_illumina_amplicon.csv
    """

    sample_mapping_dict = {}

    with open(file_in, "r") as fin:

        ## Check header
        MIN_COLS = 2
        # TODO nf-core: Update the column names for the input samplesheet
        HEADER = ["sample", "vcf_path", "bed_path", "bim_path"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(",".join(header), ",".join(HEADER)))
            sys.exit(1)

        ## Check sample entries
        for line in fin:
            lspl = [x.strip().strip('"') for x in line.strip().split(",")]

            # Check valid number of columns per row
            if len(lspl) < len(HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(HEADER)),
                    "Line",
                    line,
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )

            ## Check sample name entries
            sample, vcf_path, bed_path, bim_path = lspl[: len(HEADER)]
            sample = sample.replace(" ", "_")
            if not sample:
                print_error("Sample entry has not been specified!", "Line", line)

            ## Check file extensions
            for path in [vcf_path, bed_path, bim_path]:
                if path:
                    if path.find(" ") != -1:
                        print_error("File path contains spaces!", "Line", line)
            for path in bed_path:
                if not bed_path.endswith(".bed"):
                    print_error(".bed file does not have extension .bed",
                                "Line", line)
            for path in bim_path:
                if not bim_path.endswith(".bim"):
                    print_error("bim file does not have extension .bim",
                                "Line", line)
            for path in vcf_path:
                if not vcf_path.endswith(".vcf.gz"):
                    print_error("VCF file does not have extension .vcf.gz",
                                "Line", line)

            ## Auto-detect vcf or bfile
            sample_info = [] # is_vcf, vcf, bed, bim
            if sample and bed_path and bim_path:  ## bfiles
                sample_info = ["0", vcf_path, bed_path, bim_path]
            elif sample and vcf_path:  ## vcf
                sample_info = ["1", vcf_path, bed_path, bim_path]
            else:
                print_error("Invalid combination of columns provided! Have you got vcf and bed/bim for a sample?", "Line", line)
                        
            ## Create sample mapping dictionary = { sample: [ single_end, fastq_1, fastq_2 ] }
            if sample not in sample_mapping_dict:
                sample_mapping_dict[sample] = [sample_info]
            else:
                if sample_info in sample_mapping_dict[sample]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    sample_mapping_dict[sample].append(sample_info)

    ## Write validated samplesheet with appropriate columns
    if len(sample_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        make_dir(out_dir)
        with open(file_out, "w") as fout:
            fout.write(",".join(["sample", "is_vcf", "vcf_path", "bed_path", "bim_path"]) + "\n")

            is_vcf_set = set()
            for sample in sorted(sample_mapping_dict.keys()):
                [is_vcf_set.add(x[0]) for x in sample_mapping_dict[sample]]
            if not (len(is_vcf_set) == 1):
                print_error("All samples must be in the same format! (e.g. all VCF or all bed / bim)")

                ## Check that multiple runs of the same sample are of the same datatype
                if not all(x[0] == sample_mapping_dict[sample][0][0] for x in sample_mapping_dict[sample]):
                    print_error("Multiple runs of a sample must be of the same datatype!", "Sample: {}".format(sample))

                for idx, val in enumerate(sample_mapping_dict[sample]):
                    fout.write(",".join(sample) + "," + ",".join(val) + "\n")
    else:
        print_error("No entries to process!", "Samplesheet: {}".format(file_in))


def main(args=None):
    args = parse_args(args)
    check_samplesheet(args.FILE_IN, args.FILE_OUT)

if __name__ == "__main__":
    sys.exit(main())
