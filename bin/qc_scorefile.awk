# qc_scorefile.awk: program to QC a PGS Catalog scoring file
#
# Required input:
# chr_name | chr_position | effect_allele | reference allele | effect_weight
# Tab separated, no headers (column names)
#
#   usage:
#     mawk -v out=output.txt -f qc_scorefile.awk PGS000379.validated.txt

BEGIN {
    if (!out) {
        missing_output_error=1
        exit 1
    }
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

    if (length(effect_allele) > 1) {
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
        printf "WARN - %d HLA variants detected and ignored\n", hla_count > "qc.log"
    }
    if (multiallelic_warn) {
        printf "WARN - %d multiallelic variants detected and ignored\n",
            multiallelic_count > "qc.log"
    }
    if (weight_warn) {
        printf "WARN - %d variants with missing weights ignored\n",
            missing_weight_count > "qc.log"
    }
    if(good_variants > 0) {
        printf "%d input variants\n", raw_variants > "qc.log"
        printf "%d unique chr:pos variants \n", unique_variants > "qc.log"
        printf "%d variants pass QC\n", good_variants > "qc.log"
        printf "%.2f%% variants pass QC\n",
            (good_variants / raw_variants * 100) > "qc.log"
        printf "%d variants fail QC\n",
            hla_count + multiallelic_count + missing_weight_count > "qc.log"
    }
}
