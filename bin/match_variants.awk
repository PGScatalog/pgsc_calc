# match_variants.awk: Match variants from a scorefile against target data
#
# Usage:
#     awk -v min_overlap=0.75 -v target=topmed.combined -v mem=4G -v cpu=2 \
#         -f match_variants.awk \
#         PGS001229_22.txt matched.scorefile.tmp flipped.matched.scorefile.tmp
#
# Where parameters (-v) are:
#     target      : path to pvar / bim file that contains ALL target variants
#     cpu         : integer, n cpus to use for sorting
#     mem         : string, amount of RAM to use for sorting
#     min_overlap : float, [0 - 1], overlap below this causes a fatal error
#
# And input files are (order is important):
#     PGS001229_22.txt: Path to a scoring file
#     matched.scorefile.tmp  : This file is made in BEGIN { }, don't change
#     flipped.matched.scorefile.tmp: This file is made in BEGIN { }, don't change
#
# TO DO:
#     - skip ambiguous variants?
#     - remove multiallelics from target

BEGIN {
    if (min_overlap < 0 || min_overlap > 1 || min_overlap == "") {
        invalid_overlap = 1
        exit 1
    } else if (!cpu || !mem || !target) {
        invalid_parameter = 1
        exit 1
    }

    "date" | getline start_time

    # sort scorefile variant IDs for comm --------------------------------------
    printf "cut -f 5 --complement --output-delimiter=':' %s " \
        " | sort --parallel=%d --buffer-size=%s"              \
        " > scorefile.sorted.tmp \n",                         \
        ARGV[1], cpu, mem | "/bin/sh"

    # sort target variant IDs for comm -----------------------------------------
    printf "tail -n +2 %s "                      \
        " | cut -f 3 "                           \
        " | sort --parallel=%d --buffer-size=%s" \
        " > target.sorted.tmp\n", \
        target, cpu, mem | "/bin/sh"

    # create matched.scorefile and flipped.matched scorefiles ------------------
    print "comm -12 scorefile.sorted.tmp target.sorted.tmp" \
        " > matched.scorefile.tmp" | "/bin/sh"
    print "comm -23 scorefile.sorted.tmp target.sorted.tmp" \
        " > unmatched.scorefile.tmp" | "/bin/sh"

    # only flip unmatched variants
    print "sed -i 'y/ACTG/TGAC/' unmatched.scorefile.tmp " | "/bin/sh"

    # now try to match the flipped variants
    print "comm -12 unmatched.scorefile.tmp target.sorted.tmp" \
        " > flipped.matched.scorefile.tmp" | "/bin/sh"
    print "comm -23 unmatched.scorefile.tmp target.sorted.tmp" \
        " > flipped.unmatched.scorefile.tmp" | "/bin/sh"
    close("/bin/sh")
    OFS = "\t"
}

FILENAME == ARGV[1] {
    FS          = "\t"
    key         = $1":"$2":"$3":"$4 # chr:pos:ref:alt
    chr[key]    = $1
    pos[key]    = $2
    effect[key] = $3
    other[key]  = $4
    weight[key] = $5
}

FILENAME == ARGV[2] {
    FS = ":"
    matched[$0]++ # $0 = chr:pos:effect:other
}

FILENAME == ARGV[3] {
    FS = ":"
    flip_key = $1":"$2":"flipstrand($3)":"flipstrand($4) # match ARGV[1]
    flipped_unmatched[flip_key]++
}

END {
    # match variants -----------------------------------------------------------
    for (i in chr) {
        if (matched[i]) {
            print_scorefile(chr[i], pos[i], effect[i], other[i], weight[i], 0)
        } else if (flipped_unmatched[i]) {
            # let's try flipping, that's a good trick!
            print_scorefile(chr[i], pos[i], effect[i], other[i], weight[i], 1)
        }
    }

    # error checking -----------------------------------------------------------
    "wc -l < scorefile.sorted.tmp" | getline scorefile_variants
    "wc -l < target.sorted.tmp" | getline target_variants
    percent_matched = (matches / scorefile_variants * 100)

    if (invalid_overlap) {
        input_error("overlap")
        exit 1
    } else if (!cpu || !mem || !target) {
        input_error("parameter")
        exit 1
    } else if (NR == 0) {
        input_error("file")
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

    # write a pretty log  -------------------------------------------------------
    (bad_strand) ? bad_strand : bad_strand = 0

    print "match_variants.awk"                   , start_time > "match.log"
    print "Total variants in scoring file"       , scorefile_variants > "match.log"
    print "Total variants in target data"        , target_variants > "match.log"
    print "Total matched variants"               , matches > "match.log"
    print "Percent variants successfully matched", percent_matched > "match.log"
    print "Minimum overlap set to "              , min_overlap * 100 > "match.log"
    print "Total alleles flipped"                , bad_strand > "match.log"
    print "Total alleles not flipped"            , matches - bad_strand > "match.log"

    # and sort matched variants, now we've checked for errors -------------------

    split(ARGV[1], splits, ".")
    out_path = splits[1]".scorefile"
    printf "sort -nk 1,2 scorefile.out.tmp > %s", out_path | "/bin/sh"
    close("/bin/sh")
}

function flipstrand(nt) {
    complement["A"] = "T"
    complement["T"] = "A"
    complement["C"] = "G"
    complement["G"] = "C"

    return complement[nt]
}

function input_error(type) {
    if (type == "file") {
        print "ERROR - Empty input file"
    } else if (type == "overlap") {
        print "Please specify a valid minimum overlap with e.g. -v min_overlap=0.75"
        print "Valid range: [0, 1]"
    } else if (type == "parameter") {
        print "Invalid parameter options (-v) for cpu, mem, or target"
    }
}

function print_scorefile(chr, pos, effect, other, weight, flip) {
    matches++
    if (flip) {
        id = chr":"pos":"flipstrand(effect)":"flipstrand(other)
        print id, flipstrand(effect), weight > "scorefile.out.tmp"
        bad_strand++
    } else {
        id = chr":"pos":"effect":"other
        print id, effect, weight > "scorefile.out.tmp"
    }
}
