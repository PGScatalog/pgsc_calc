#!/usr/bin/env awk

# get the intersection of variants from two plink variant information files
# handles variants that have been ref / alt swapped but not flipped
#
# usage:
# awk -v target_format='pvar' -f intersect_variants.awk <path/to/reference/pvar> </path/to/target/pvar>
#
# use process substition to pass decompressed data to awk, if needed
# e.g. <(zstdcat compressed.pvar.zst)

BEGIN {
    if (ARGC != 3) {
        print "Invalid input arguments"
        print "Usage:"
        print "awk -f intersect_variants.awk <path/to/reference/pvar> </path/to/target/pvar>"
        _input_err=1
        exit 1
    }

    if (target_format != "pvar" && target_format != "bim") {
        print "Set target format with -v flag, e.g. awk -v target_format='pvar'..."
        _input_err=1
        exit 1
    }

    cleanup()
}

# process reference
# only process lines containing variants (without # prefix)
FNR == NR && !/^#/ {
    # splitting handles multiallelic variants
    split($5, ALT, ",")

    for (a in ALT) {
        # comparison operators work on strings in awk, e.g. 'A' < 'C' is true
        print_reference_join_id(a, ALT)
    }
    next
}

# process target
FNR != NR && !/^#/ {
    # this field is shared by bim and pvar files
    split($5, ALT, ",")

    for (a in ALT) {
        # comparison operators work on strings in awk, e.g. 'A' < 'C' is true
        print_target_join_id(a, ALT)
    }
    next
}

function print_reference_join_id(a, ALT) {
    if($4 < ALT[a])
        print $1":"$2":"$4":"ALT[a], $3, $4, (length($4) > 1 || length(ALT[a]) > 1) | "sort > ref_variants.txt"
    else
        print $1":"$2":"ALT[a]":"$4, $3, $4, (length($4) > 1 || length(ALT[a]) > 1) | "sort > ref_variants.txt"
}

function print_target_join_id(a, ALT) {
    if (target_format=="pvar") {
        chrom=$1
        pos=$2
        id=$3
        ref=$4
        # (alt is function parameter, equivalent to split($5))
    } else {
        # ew, bim
        chrom=$1
        pos=$4
        id=$2
        ref=$6 # not strictly true, but alt is taken from $5
        # (alt is function parameter, equivalent to split($5))
    }

    if(ref < ALT[a]) {
        print chrom":"pos":"ref":"ALT[a], id, ref | "sort > target_variants.txt"
    }
    else {
        print chrom":"pos":"ALT[a]":"ref, id, ref | "sort > target_variants.txt"
    }
}


function join_ref_target() {
    system("join ref_variants.txt target_variants.txt > joined.txt")
}

function match_report() {
    line_nr = 1 # NR not reset by getline
    while (getline < "joined.txt") {
        if (line_nr == 1) {
            print $0, "SAME_REF" > "matched_variants.txt"
        } else {
            print $0, ($3 == $6) > "matched_variants.txt"
        }
        line_nr++
    }
}

function cleanup() {
    system("rm -f targetvariants.tmp refvariants.tmp target_variants.txt ref_variants.txt joined.txt")
}


END {
    if (_input_err) {
        exit 1
    }

    if (target_format=="pvar") {
        print "Target variants are in pvar format"
    } else {
        print "Target variants are in bim format"
    }

    join_ref_target()
    match_report()
    cleanup()
}
