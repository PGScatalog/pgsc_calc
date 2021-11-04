# check_extract.awk
#
# Validate variant list from a PGS Catalog scorefile against variants in target
# genomic data.
#
# Assuming variants in the target genomic data have been extracted using plink2
# --extract, it's important to check:
#
#     - Do the extracted variants overlap well with the scorefile?
#         - If not, explode loudly
#     - Do effect alleles match REF or ALT in the target genomic data?
#         - If not, flip (complement) the effect allele
#         - Otherwise, write the validated position, effect allele, and weight
#
# usage: mawk -v threshold=0.75 -f check_extract.awk extract.pvar pgsscorefile.txt
#
# pgs_scorefile.txt should have the following format (tab separated):
#
#     CHR | POS | EFFECT_ALLELE | OTHER_ALLELE | EFFECT_WEIGHT
#
# with no header (column names). The SCOREFILE_CHECK and SCOREFILE_QC pipeline
# processes produce a file in this format. extract.pvar is standard plink2
# format. Threshold specifies the minimum acceptable overlap betweem scorefile
# and variants, ranges from 0 - 1.
#
# Expected output files: scorefile.txt (validated), extract.log (logfile)

BEGIN {
    "date" | getline start_time
    if (!threshold) {
        missing_threshold = 1
        exit 1
    }
}

# do this in the extracted variants only (skipping header, first file argument)
NR == FNR && NR > 1 {
    lines[$3]=1 # ID column is key
    ref[$3]=$4
    alt[$3]=$5
    extracted_var++
    next # don't do anything else with the current line in first file
}

# do this for the validated PGS file (second file argument)
{
    original_var++
    pgs_key=$1":"$2
    for (extracted_key in lines) {
        if (pgs_key == extracted_key) {
            # effect alleles now intersected with extracted variants
            intersected_id[extracted_key] = extracted_key
            effect[extracted_key] = $3
            other[extracted_key] = $4
            effect_weight[extracted_key] = $5
            delete lines[pgs_key] # match only once
            matched_variant++
        }
    }
}

END {
    if (NR == 0 && !missing_threshold) {
        input_error("file")
        exit 1
    }
    if (missing_threshold) {
        input_error("threshold")
        exit 1
    }

    if (NR > 0 && !missing_threshold) { # finished error checking
        simple_match = extracted_var / original_var
        intersected =  matched_variant / original_var * 100
        for (pos in effect) {
            if(effect[pos] != ref[pos] && effect[pos] != alt[pos]) {
                effect[pos] = flipstrand(effect[pos])
                bad_strand++
            } else {
                print intersected_id[pos], effect[pos], effect_weight[pos] > "scorefile.txt"
            }
        }
        # write a pretty log! --------------------------------------------------
        print start_time > "extract.log"
        printf "%-40s: %d\n", "Total variants in scoring file", original_var > "extract.log"
        printf "%-40s: %d\n", "Total variants in extracted target data", extracted_var > "extract.log"
        printf "%-40s: %d\n", "Total unique intersected variants", matched_variant > "extract.log"
        printf "%-40s: %.2f%%\n", "Percent variants successfully matched", intersected > "extract.log"
        printf "%-40s: %.2f%%\n", "Minimum overlap set to", threshold * 100 > "extract.log"
        printf "%-40s: %d\n", "Total effect alleles flipped", bad_strand > "extract.log"

        # explode loudly -------------------------------------------------------
        if (intersected < (threshold * 100)) {
            overlap_error()
            exit 1
        }
    }
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
}

function input_error(type) {
    if (type == "file") {
        print "ERROR - Empty input file"
    } else if (type == "threshold") {
        print "Please specify a threshold with e.g. -v threshold=0.75"
    } else {
        print "Weird input error that should never happen"
    }
}
