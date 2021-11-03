# check_extract.awk
#
# Compare variant list from PGS with pvar extract from target genomic data
# If less than 50% of variants are present, explode loudly
#
# usage: mawk -f check_extract.awk extract.pvar variants.txt -v threshold=0.75

BEGIN {
    "date" | getline start_time

    if (!threshold) {
        missing_threshold = 1
        exit 1
    }
}

# do this for the extracted variants only (skipping header)
NR == FNR && NR > 1 {
    lines[$3]=1 # ID column is key
    extracted_var++
    next # don't do anything else with the current line
}

# do this in the original PGS file only
{
    original_var++
    pgs_key=$1":"$2
    for (extracted_key in lines) {
        if (pgs_key == extracted_key) {
            delete lines[key] # match only once
            matched_variant++
        }
    }

}

END {
    if (NR > 0) {
        simple_match = extracted_var / original_var # compare line count across files
        intersected =  matched_variant / original_var * 100 # match with associative array

        print start_time > "extract.log"
        printf "%-40s: %d\n", "Total variants in scoring file", original_var > "extract.log"
        printf "%-40s: %d\n", "Total variants in extracted target data", extracted_var > "extract.log"
        printf "%-40s: %d\n", "Total unique intersected variants", matched_variant > "extract.log"
        printf "%-40s: %.2f%%\n", "Percent variants successfully matched", intersected > "extract.log"
        printf "%-40s: %.2f%%\n", "Minimum overlap set to", threshold * 100 > "extract.log"
    }
    if (missing_threshold) {
        print "Please specify a threshold with e.g. -v threshold=0.75"
    }
    if (NR == 0 && !missing_threshold) {
        print "ERROR - Empty input file"
        exit 1
    }
    if (!missing_threshold && intersected < (threshold * 100)) {
        print "ERROR - Your target genomic data seems to overlap poorly with the provided scoring file"
        print "ERROR - Please check the log file for details (extract.log)"
        exit 1
    }
}
