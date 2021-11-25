# match_variants.awk: Match variants from a scorefile against target data
#
# Requires sqlite3 and coreutils. Usage:
#
#     awk -v min_overlap=0.75 -v target=topmed.combined \
#         -f match_variants.awk \
#         PGS001229_22.txt match_variants.sql
#
# Parameters (-v):
#     min_overlap : float, [0 - 1], overlap below this causes a fatal error
#     target      : path to pvar / bim file that contains ALL target variants
#
# Input files:
#     PGS001229_22.txt: Path to a scoring file
#     match_variants.sql: Path to SQL script (distributed with pipeline in bin/)
#
# TO DO:
#     - skip ambiguous variants?
#     - remove multiallelics from target

BEGIN {
    "date" | getline start_time
    OFS = "\t"
    if (min_overlap < 0 || min_overlap > 1 || min_overlap == "") {
        invalid_overlap = 1
        exit 1
    }

    # stage input data with static names for sqlite ----------------------------
    print "chrom", "pos", "effect", "other", "weight" > "scorefile.txt"
    printf "cat %s >> scorefile.txt \n", ARGV[1] | "/bin/sh"
    printf "cp %s target.txt \n", target | "/bin/sh"
    close("/bin/sh")
}

FILENAME == ARGV[1] { scorefile_variants++ }

# this is dumb but it's an easy way to stage the match_variants sql script in
# a working directory with a static name
FILENAME == ARGV[2] { print > "match_variants.sql" }

END {
    # match the scorefile variants against target data using sqlite ------------
    if (system("sqlite3 < match_variants.sql") != 0) {
        print "ERROR - sqlite matching failed"
        exit 1
    }

    # now check how well the matching worked -----------------------------------
    "wc -l < target.txt" | getline target_variants
    "wc -l < matched.scorefile.tmp" | getline matches
    percent_matched = (matches / scorefile_variants * 100)

    if (invalid_overlap) {
        input_error("overlap")
        exit 1
    } else if (NR == 0) {
        input_error("file")
        exit 1
    } else if (!target) {
        input_error("parameter")
        exit 1
    } else if (percent_matched < min_overlap * 100) {
        printf "ERROR - Your target genomic data seems to overlap poorly with" \
            " the provided scoring file \n" \
            "ERROR - See --min_overlap parameter \n" \
            "%.2f%% is minimum overlap\n" \
            "%.2f%% variants matched\n", \
            (min_overlap * 100), percent_matched
        exit 1
    }

    # tidy up output: rename matched scorefile to <PGSID>.scorefile ------------
    split(ARGV[1], splits, ".")
    out_path = splits[1]".scorefile"
    printf "cp matched.scorefile.tmp %s", out_path | "/bin/sh"
    close("/bin/sh")

    # produce a nice summary report --------------------------------------------
    print "match_variants.awk"                   , start_time > "match.log"
    print "Total variants in scoring file"       , scorefile_variants > "match.log"
    print "Total variants in target data"        , target_variants > "match.log"
    print "Total matched variants"               , matches > "match.log"
    print "Percent variants successfully matched", percent_matched > "match.log"
    print "Minimum overlap set to "              , min_overlap * 100 > "match.log"
}

function input_error(type) {
    if (type == "file") {
        print "ERROR - Empty input file"
    } else if (type == "overlap") {
        print "Please specify a valid minimum overlap with e.g. -v min_overlap=0.75"
        print "Valid range: [0, 1]"
    } else if (type == "parameter") {
        print "Invalid parameter options (-v) for target"
    }
}
