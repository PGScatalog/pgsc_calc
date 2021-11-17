# combine_scorefile.awk
#
# Awk program to sum PLINK2's .sscore files that were split (e.g. by chromosome)
#
# Usage:
#     awk -f combine_scorefile.awk <scorefile1> ... <scorefileN>
#
# Expected input format (https://www.cog-genomics.org/plink/2.0/formats#sscore):
#     #FID     IID      NMISS_ALLELE_CT  NAMED_ALLELE_DOSAGE_SUM  SCORE1_AVG

FNR == 1 && NR == 1 { print $1, $2, $3, $4 } # print the first header except avg
FNR == 1 && NR != 1 { next }  # and skip headers in other files
                    {
                        FID[$2]         = $1
                        IID[$2]         = $2
                        ALLELE_CT[$2]  += $3
                        DOSAGE_SUM[$2] += $4
                    }
END                 { for (i in IID) {
                          print FID[i], i, ALLELE_CT[i], DOSAGE_SUM[i]
                      }
                    }
