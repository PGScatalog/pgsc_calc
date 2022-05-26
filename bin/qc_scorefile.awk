# qc_scorefile.awk: program to QC a PGS Catalog scoring file
#
# Required input:
# chr_name | chr_position | effect_allele | reference allele | effect_weight
# Tab separated, no headers (column names)
#
#   usage:
#     mawk -v out=output.txt -f qc_scorefile.awk PGS000379.validated.txt

BEGIN {
    FS="\t"; OFS="\t"
    "date" | getline start_time
    if (!out) {
        missing_output_error=1
        exit 1
    }
    print "qc_scorefile.awk", start_time > "qc.log"
}

# counts number of total lines processed
{ raw_variants++ }

# skip any duplicate input lines (only keep first occurrence)
# duplicate defined by chr_name + chr_pos concatenated
!visited[$1$2]++ {
    unique_variants++

    chr_name=$1
    chr_pos=$2
    effect_allele=$3
    ref_allele=$4
    effect_weight=$5

    if (length(effect_allele) > 1 || length(ref_allele) > 1) {
        multiallelic_warn = 1
        multiallelic_count++
        next # skip line
    }

    if (!effect_weight) {
        weight_warn = 1
        missing_weight_count++
        next
    }

    if ( effect_allele ~ "P|N" ) {
        hla_warn = 1
        hla_count++
        next
    }

    good_variants++
    print $0 > out
}

END {
    if(missing_output_error) {
        print "ERROR - Set output with -v out=<path>"
        exit 1
    }
    if(!missing_output_error && raw_variants == 0) {
        print "ERROR - Empty input file"
        exit 1
    }
    if(raw_variants > 0 && good_variants == 0) {
        print "ERROR - No variants survived QC!"
        exit 1
    }
    if (hla_warn) {
        print "WARN - HLA variants detected and ignored", hla_count > "qc.log"
    }
    if (multiallelic_warn) {
        print "WARN - multiallelic variants detected and ignored",
            multiallelic_count > "qc.log"
    }
    if (weight_warn) {
        print "WARN - variants with missing weights ignored",
            missing_weight_count > "qc.log"
    }
    print "Input variants", raw_variants > "qc.log"
    print "Unique chr:pos variants", unique_variants > "qc.log"
    print "Variants pass QC", good_variants > "qc.log"
    print "% variants pass QC",
        (good_variants / raw_variants * 100) > "qc.log"
    print "% variants fail QC",
        hla_count + multiallelic_count + missing_weight_count > "qc.log"
}
