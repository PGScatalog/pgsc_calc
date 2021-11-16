# check_overlap.awk
#
# Intersect variant IDs from a PGS Catalog scorefile against target genomic
# data. It's important to check:
#
#     - Do the target variants overlap well with the scorefile?
#         - If not, explode loudly
#         - By default threshold is 0 (overlap is not checked without parameter)
#     - Do effect alleles match REF or ALT in the target genomic data?
#         - If not, flip (complement) the effect allele
#         - Otherwise, print the validated position, effect allele, and weight
#
# usage: mawk -v threshold=0.75 -f check_overlap.awk target.pvar pgsscorefile.txt
#
# pgsscorefile.txt should have the following format (tab separated):
#
#     CHR | POS | EFFECT_ALLELE | OTHER_ALLELE | EFFECT_WEIGHT
#
# with no header (column names). The SCOREFILE_CHECK and SCOREFILE_QC pipeline
# processes produce a file in this format. target.pvar is standard plink2
# format. Threshold specifies the minimum acceptable overlap between scorefile
# and variants, ranges from 0 - 1.
#
# Expected output: printed scorefile, extract.log

BEGIN {
    FS="\t"; OFS="\t"
    "date" | getline start_time

    if (threshold < 0 || threshold > 1) {
        invalid_threshold = 1
        exit 1
    }
}

# do this in the target data (skipping header, first file argument)
NR == FNR && NR > 1 {
    lines[$3]=1 # true
    ref[$3]=$4
    alt[$3]=$5
    extracted_var++
    next # don't do anything else with the current line
}

# simple line count of scorefile for log
{ original_var++ }

# if the variant in the target data intersects the scorefile, add to some maps
lines[$1":"$2] {
    pgs_key=$1":"$2
    intersected_id[pgs_key] = pgs_key
    effect[pgs_key] = $3
    other[pgs_key] = $4
    effect_weight[pgs_key] = $5
    matched_variant++
    delete lines[pgs_key] # match only once
}

END {
    # error checking -----------------------------------------------------------
    if (NR == 0 || FNR == 0) {
        input_error("file")
        exit 1
    }
    if (invalid_threshold) {
        input_error("threshold")
        exit 1
    }
    # !!! explode loudly !!!
    if (intersected < (threshold * 100)) {
        overlap_error()
        exit 1
    }

    # flip if required, and print intersected alleles in plink2 scorefile format
    for (pos in effect) {
        if(effect[pos] != ref[pos] && effect[pos] != alt[pos]) {
            effect[pos] = flipstrand(effect[pos])
            bad_strand++
        } else {
            print intersected_id[pos], effect[pos], effect_weight[pos] > "scorefile"
        }
    }

    # write a pretty log! ------------------------------------------------------
    intersected =  matched_variant / original_var * 100
    if (!bad_strand) bad_strand = 0

    print "check_extract.awk", start_time > "extract.log"
    print "Total variants in scoring file", original_var > "extract.log"
    print "Total variants in extracted target data", extracted_var > "extract.log"
    print "Total unique intersected variants", matched_variant > "extract.log"
    print "Percent variants successfully matched", intersected > "extract.log"
    print "Minimum overlap set to", threshold * 100 > "extract.log"
    print "Total effect alleles flipped", bad_strand > "extract.log"
    print "Total effect alleles not flipped", good_strand > "extract.log"
}

function flipstrand(nt) {
    complement["A"] = "T"
    complement["T"] = "A"
    complement["C"] = "G"
    complement["G"] = "C"

    return complement[nt]
}

function overlap_error() {
    print "ERROR - Your target genomic data seems to overlap poorly with the provided scoring file"
    print "ERROR - Please check the log file for details (extract.log)"
    print "ERROR - See --min_overlap parameter"
}

function input_error(type) {
    if (type == "file") {
        print "ERROR - Empty input file"
    } else if (type == "threshold") {
        print "Please specify a valid threshold with e.g. -v threshold=0.75"
        print "Valid range: [0, 1]"
    } else {
        print "Weird input error that should never happen"
    }
}
