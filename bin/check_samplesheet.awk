BEGIN {
    OFS=FS=","
    print "sample", "is_vcf", "chrom", "datadir", "vcf_path", "bfile_prefix" > "samplesheet.valid.csv"
}

# set up column names into an array f
NR==1 {
    for (i=1; i<=NF; i++) {
        f[$i] = i
    }
}

NR > 1 {
    # check missing required columns (execute this pattern for each row)--------
    if (! $(f["sample"])) {
        print "Please check line number", NR
        error_missing_sample = 1
        exit 1
    } else if (! $(f["datadir"])) {
        print "Please check line number", NR
        error_missing_datadir = 1
        exit 1
    } else if (! $(f["vcf_path"]) && ! $(f["bfile_prefix"])) {
        print "Please check line number", NR
        error_missing_path = 1
        exit 1
    }

    # check invalid column combinations ----------------------------------------
    if ($(f["vcf_path"]) && $(f["bfile_prefix"])) {
        print "Please check line number", NR
        print "ERROR: Both vcf_path and bfile_prefix present"
        error_both_path = 1
        exit 1
    }

    # check invalid data entry -------------------------------------------------
    # file extensions
    if ( $(f["vcf_path"]) != "" && $(f["vcf_path"]) !~ ".vcf.gz$" ) {
        print "Please check line number", NR
        printf "ERROR - BAD FILE EXTENSION IN COLUMN %s \n%s\n", "vcf_path", $(f["vcf_path"])
        print "Valid VCF files should end with .vcf.gz"
        error_vcf_extension = 1
        exit 1
    } else if ( $(f["bfile_prefix"]) == "\\." ) {
        print "Please check line number", NR
        printf "ERROR - BAD FILE EXTENSION IN COLUMN %s \n%s\n", "bfile_prefix", $(f["bfile_path"])
        print "Did you accidentally include .bed / .bim / .fam ?" # be helpful
        error_bfile_extension = 1
        exit 1
    }

    # file paths
    if ( $(f["vcf_path"]) ~ " " || $(f["bfile_prefix"]) ~ " ") {
        print "Please check line number", NR
        print "ERROR - File path shouldn't contain spaces!"
        error_space_path = 1
        exit 1
    }
    if ( $(f["vcf_path"]) ~ "^/" || $(f["bfile_prefix"]) ~ "^/") {
        print "Please check line number", NR
        print "ERROR - It looks like your path starts with / - please don't use absolute paths!"
        error_absolute_path = 1
        exit 1
    }

    # keep track of useful things per sample -----------------------------------
    if ( $(f["vcf_path"]) ) {
        is_vcf[$(f["sample"]) ":" NR ] = 1
        n_vcf[$(f["sample"])]++
    } else {
        is_vcf[$(f["sample"]) ":" NR ] = 0
    }

    chrom[$(f["chrom"])]=1 # unique list of chromosomes encountered for everybody
    samples[$(f["sample"])]++
    sample_chrom[$(f["sample"])":"$(f["chrom"])]++

    # print out validated data -------------------------------------------------
    print $(f["sample"]), is_vcf[$(f["sample"]) ":" NR], $(f["chrom"]),
        $(f["datadir"]), $(f["vcf_path"]),
        $(f["bfile_prefix"]) > "samplesheet.valid.csv"
}

END {
    # explode loudly for obvious problems --------------------------------------
    if (error_missing_sample) {
        error_required("sample")
    } else if (error_missing_datadir) {
        error_required("datadir")
    } else if (error_missing_path) {
        error_required("vcf_path or bfile_prefix")
    } else if (error_vcf_extension) {
        exit 1
    } else if (error_both_path) {
        exit 1
    } else if (error_space_path) {
        exit 1
    } else if (error_absolute_path) {
        exit 1
    }

    NR>2 ? empty = 0 : empty = 1
    if (empty) {
        print "ERROR - EMPTY INPUT SAMPLESHEET"
        exit 1
    }

    # check more subtle things for each sample ---------------------------------
    for (i in samples) {
        # check multiple samples are of the same datatype
        if (n_vcf[i] != samples[i]) {
            printf "ERROR - Samples with sample ID %s not of same datatype\n", samples[i]
            print "Did you mix vcf_path and bfile_prefix?"
            exit 1
        }
        # check a sample has unique chromosomes
        for (k in chrom) {
            if (sample_chrom[i":"k] > 1) {
                printf "ERROR - Duplicate chromosomes detected in sample %s\n", i
                print "Check column chrom"
                exit 1
            }
            if (k != "") { # skip null chromosomen
                (sample_chrom[i":"k]) ? chrom_specified = 1 : chrom_specified = 0
            }
        }
        # check a sample doesn't mix null with named chromosomes
        if (sample_chrom[i":"""] > 0 && chrom_specified) {
            printf "ERROR - Both null and named chromosomes detected in sample %s\n", i
            print "Only use blank chromosome if data have not been split by chromosome"
            exit 1
        }
    }
}

function error_required(str) {
    printf "ERROR - MISSING REQUIRED COLUMN IN SAMPLESHEET - %s\n", str
    exit 1
}
