#!/usr/bin/env bash

# get the intersection of variants from two plink variant information files
# handles variants that have been ref / alt swapped but not flipped
#
# usage:
# bash intersect_variants.sh <path/to/reference/pvar> </path/to/target> <pvar or bim> <chrom or ALL>
#
# use process substition to pass decompressed data to sh, if needed
# e.g. <(zstdcat compressed.pvar.zst)

set -euxo pipefail

# Inputs
i_reference=$1 # path/to/REFERENCE/pvar (or decompressed stdin)
i_target=$2 # path/to/TARGET/pvar (or decompressed stdin)
target_format=$3 # format of target pvar
chrom=$4 # whether to limit matches to specific chromosome of the reference

mkdir tmp # temporary working directory

chr_list="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y"
validate_chrom() { echo "1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X Y" | grep -F -q -w "$1"; }

# reference is always pvar
echo -e "CHR:POS:A0:A1\tID_REF\tREF_REF\tIS_INDEL\tSTRANDAMB\tIS_MA_REF" > ref_variants.txt
## Decide how to handle chromosome
if [ "$chrom" == "ALL" ]; then
  awk '!/^#/ {split($5, ALT, ",");
    for (a in ALT){
      if($4 < ALT[a]) print $1":"$2":"$4":"ALT[a], $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC"), (length(ALT) > 1);
      else print $1":"$2":"ALT[a]":"$4, $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC"), (length(ALT) > 1)
    }}' $i_reference | sort -T ./tmp/ >> ref_variants.txt
elif validate_chrom $chrom; then
  awk -v filter_chrom=$chrom '!/^#/ && ($1 == filter_chrom) {split($5, ALT, ",");
    for (a in ALT){
      if($4 < ALT[a]) print $1":"$2":"$4":"ALT[a], $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC"), (length(ALT) > 1);
      else print $1":"$2":"ALT[a]":"$4, $3, $4, (length($4) > 1 || length(ALT[a]) > 1), ($4 ALT[a] == "AT" || $4 ALT[a] == "TA" || $4 ALT[a] == "CG" || $4 ALT[a] == "GC"), (length(ALT) > 1)
    }}' $i_reference | sort -T ./tmp/ >> ref_variants.txt
else
  echo "${chrom} is not a valid option, only {$chr_list} are currently accepted"
  exit 1
fi


if [ $(wc -l < ref_variants.txt) -eq 1 ]
then
    echo "ERROR: No variants in reference report"
    exit 1
fi

# handle target (in multiple formats)
echo -e "CHR:POS:A0:A1\tID_TARGET\tREF_TARGET\tIS_MA_TARGET" > target_variants.txt
if [ "$target_format" == "pvar" ]; then
  awk '!/^#/ {split($5, ALT, ",");
    for (a in ALT){
      if($4 < ALT[a]) print $1":"$2":"$4":"ALT[a], $3, $4, (length(ALT) > 1);
      else print $1":"$2":"ALT[a]":"$4, $3, $4, (length(ALT) > 1)
    }}' $i_target | sort -T ./tmp/ >> target_variants.txt
elif [ "$target_format" == "bim" ]; then
  awk '!/^#/ {
    if($5 < $6) print $1":"$4":"$5":"$6, $2, $6, 0;
    else print $1":"$4":"$6":"$5, $2, $6, 0
  }' $i_target | sort -T ./tmp/ >> target_variants.txt
else
  echo "${target_format} is not a valid option (only pvar and bim are currently accepted)"
  exit 1
fi

if [ $(wc -l < target_variants.txt) -eq 1 ]
then
    echo "ERROR: No variants in target report"
    exit 1
fi

# Merge & output matches w/ ref orientation
join ref_variants.txt target_variants.txt |\
    awk '{if (NR==1) print $0, "SAME_REF"; else print $0, ($3 == $8)}' > matched_variants.txt

wc -l < target_variants.txt | awk '{ print $0-1}' > intersect_counts_${chrom}.txt
wc -l < ref_variants.txt | awk '{ print $0-1}' >> intersect_counts_${chrom}.txt
wc -l < matched_variants.txt | awk '{ print $0-1}' >> intersect_counts_${chrom}.txt

# Current output columns are:
#1 : CHR:POS:A0:A1
#2 : ID_REF
#3 : REF_REF
#4 : IS_INDEL
#5 : STRANDAMB
#6 : IS_MA_REF
#7 : ID_TARGET
#8 : REF_TARGET
#9 : IS_MA_TARGET
#10 : SAME_REF
