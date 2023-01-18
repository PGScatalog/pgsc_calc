#!/usr/bin/env bash

# get the intersection of variants from two plink variant information files
# handles variants that have been ref / alt swapped but not flipped
#
# usage:
# bash intersect_variants.sh <path/to/reference/pvar> </path/to/target> <pvar or bim>
#
# use process substition to pass decompressed data to sh, if needed
# e.g. <(zstdcat compressed.pvar.zst)

set -euxo pipefail

# Inputs
i_reference=$1
i_target=$2
target_format=$3

# reference is always pvar
echo -e "CHR:POS:A0:A1\tID_REF\tREF_REF\tIS_INDEL\tSTRANDAMB" > ref_variants.txt
    awk '!/^#/ {split($5, ALT, ",");
          for (a in ALT){
            if($4 < ALT[a]) print $1":"$2":"$4":"ALT[a], $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC");
            else print $1":"$2":"ALT[a]":"$4, $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC")
          }}' $i_reference | sort >> ref_variants.txt

# handle target (in multiple formats)
echo -e "CHR:POS:A0:A1\tID_TARGET\tREF_TARGET" > target_variants.txt
if [ "$target_format" == "pvar" ]; then
    awk '!/^#/ {split($5, ALT, ",");
          for (a in ALT){
            if($4 < ALT[a]) print $1":"$2":"$4":"ALT[a], $3, $4; else print $1":"$2":"ALT[a]":"$4, $3, $4
          }}' $i_target | sort >> target_variants.txt
elif [ "$target_format" == "bim" ]; then
    awk '!/^#/ { if($5 < $6) print $1":"$4":"$5":"$6, $2, $6; else print $1":"$4":"$6":"$5, $2, $6}' $i_target | sort >> target_variants.txt
else
  echo "${target_format} is not a valid option (only pvar and bim are currently accepted)"
  exit 1
fi

# Merge & output matches w/ ref orientation
join ref_variants.txt target_variants.txt |\
    awk '{if (NR==1) print $0, "SAME_REF"; else print $0, ($3 == $7)}' > matched_variants.txt

# Cleanup intermediate files
rm -f ref_variants.txt target_variants.txt