# check_scorefile.awk: program to validate a PGS Catalog scoring file
#
# The main function of this script is to complain loudly and quickly if input
# data don't follow an expected PGS Catalog format. The script expects the
# following columns:
#
#     - chr_name and chr_pos
#     - effect_weight
#     - effect_allele and (reference_allele or other_allele)
#
# Original genome build must be GRCh37.
#
# usage:
#     mawk -v out=output.txt -f check_scorefile.awk PGS000379.txt
#
# Output is a tab separated scorefile with the format:
#
#     CHR | POS | EFFECT_ALLELE | OTHER_ALLELE | EFFECT_WEIGHT
#
# and a log file (check.log)

BEGIN {
    FS="\t"; OFS="\t"
    "date" | getline start_time
    # longest header finishes at line 12 in PGS Catalog 2021-10-28
    # this limit is useful to prevent matching that's not needed
    header_limit = 20

    if (!out) {
        missing_output_error = 1
        exit 1
    }
}

# check headers ----------------------------------------------------------------
NR == 1 && $0 !~ /^### PGS CATALOG SCORING FILE/ {
    file_error = 1
    exit 1
}

NR < header_limit && $0 ~ /^# Original Genome Build/ {
    split($0, build_array, " = ")
    pgs_build=build_array[2]
    if (pgs_build != "GRCh37") {
        build_error = 1
        exit 1
    }
}

# assume the column names begin on the line after the header ends
NR < header_limit && $0 ~/^#/ {
    header_line=NR+1
}

# check scoring data -----------------------------------------------------------
# set up column names in an array
# useful because column numbers won't be consistent across files
# e.g. $2 -> $(data["rsid"])
$0 !~ /^#/ && NR == header_line {
    for (i=1; i<=NF; i++) {
        data[$i] = i
    }
}

$0 !~ /^#/ && NR > header_line {
    n_var_raw++
    # check mandatory columns
    if (!data["chr_position"] || !data["chr_name"]) {
        missing_position_error = 1
        exit 1
    }
    if (!data["effect_weight"]) {
        missing_weight_error = 1
        exit 1
    }
    if (!data["effect_allele"]) {
        missing_effect_error = 1
        exit 1
    }
    if (!data["reference_allele"]) {
        if (!data["other_allele"]) {
            missing_reference_error = 1
            exit 1
        }
    # overwrite missing reference with other allele column if present
    data["reference_allele"]=data["other_allele"]
    }

    # print validated columns in an consistent format
    print $(data["chr_name"]), $(data["chr_position"]),
        $(data["effect_allele"]), $(data["reference_allele"]),
        $(data["effect_weight"]) > out
    n_var++
}

END {
    # exit in END prevents other rules running
    if (missing_output_error) {
        print "Specify an output file path with -v out=output.txt"
        exit 1
    }
    if (file_error) {
        print "ERROR - This file doesn't look like a valid PGS Catalog file"
        exit 1
    }
    if (build_error) {
        print "ERROR - PGS Catalog scoring file must be in build GRCh37"
        exit 1
    }
    if (missing_position_error) {
        error_required("chr_name or chr_position")
        exit 1
    }
    if (missing_weight_error) {
        error_required("effect_weight")
        exit 1
    }
    if (missing_effect_error) {
        error_required("effect_allele")
        exit 1
    }
    if (missing_reference_error) {
        error_required("reference_allele or other_allele")
        exit 1
    }
    # write a pretty log -------------------------------------------------------
    print "check_scorefile.awk", start_time > "check.log"
    print "Total variants read", n_var_raw > "check.log"
    print "Total variants written", n_var > "check.log"
}

function error_required(str) {
    printf "ERROR - MISSING REQUIRED COLUMN IN PGS CATALOG SCORING FILE - %s\n", str
}
