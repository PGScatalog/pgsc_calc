#!/usr/bin/mawk -f

# split a plink bim file (normally per-chromosome)
# important fields:
#     - $1: chromosome integer code
# example:
#     split_bim.awk < example.bed -v split_mode=chromosome

BEGIN {
    if (split_mode == "chromosome") {
        split_chrom = 1
    } else if (split_mode == "chunk") {
	split_chunk = 1
    } else {
	print "Invalid split mode: [chromosome, chunk]"
	exit 1 
    }
}

# only keep autosomes 
$1 ~ /[0-9]+$/ {
    if (split_chrom) {
	print > $1
    } 

    if (split_chunk) {
        if ( NR % 100000 == 1 ) {
	    x++
	    f = $1 "_" x
	    print > f
	}
    }
}
