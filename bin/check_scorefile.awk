# check_scorefile.awk: program to validate a PGS Catalog scoring file
#
# Check the structure of the scoring file and extract some required data:
#     - chr_name and chr_pos
#     - effect_weight
#     - effect_allele and (reference_allele or other_allele)
# Genome build must be GRCh37
#
#   usage:
#     mawk -v out=output.txt -f check_pgscatalog.awk PGS000379.txt
BEGIN {
    FS="\t"; OFS="\t"
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

    if ( $(data["effect_allele"]) ~ "P|N" ) {
        # just warn and skip line, don't exit
        hla_warn = 1
        hla_count++
        next
    }

    # print validated columns in an consistent format
    print $(data["chr_name"]), $(data["chr_position"]),
        $(data["effect_allele"]), $(data["reference_allele"]),
        $(data["effect_weight"]) > out
    n_var++
}

END {
    if (missing_output_error) {
        print "Specify an output file path with -v out=output.txt"
    }
    if (file_error) {
        print "ERROR - This file doesn't look like a valid PGS Catalog file"
    }
    if (build_error) {
        print "ERROR - PGS Catalog scoring file must be in build GRCh37"
    }
    if (missing_position_error) {
        error_required("chr_name or chr_position")
    }
    if (missing_weight_error) {
        error_required("effect_weight")
    }
    if (missing_effect_error) {
        error_required("effect_allele")
    }
    if (missing_reference_error) {
        error_required("reference_allele or other_allele")
    }
    if (hla_warn) {
        printf "WARN - %d HLA variants detected and ignored\n", hla_count > "log"
    }
    printf "%d variants read\n", n_var_raw > "log"
    printf "%d variants written\n", n_var > "log"
}

function error_required(str) {
    printf "ERROR - MISSING REQUIRED COLUMN IN PGS CATALOG SCORING FILE - %s\n", str
}
