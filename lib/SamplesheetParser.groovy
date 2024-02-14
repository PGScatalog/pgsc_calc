import java.nio.file.Paths
import java.nio.file.NoSuchFileException

class SamplesheetParser {
    def hi() {
        return "Hello, workshop participants!"
    }

    def parseSamplesheet(row, samplesheet_path, n_chrom) {
        // [[meta], [path, to targets]]
        def chrom = truncateChrom(row)
        def dosage = importDosage(row)
        def paths = getFilePaths(row, samplesheet_path)
    
        path_list = paths["path"]
        path_map = paths.subMap("is_bfile", "is_pfile", "is_vcf", "format")
        return [[sampleset: row.sampleset, chrom: chrom, vcf_import_dosage: dosage, n_chrom: n_chrom] + path_map, path_list]
    }
}

def importDosage(row) {
    def vcf_import_dosage = false
    if (row.containsKey("vcf_genotype_field")) {
        if (row["vcf_genotype_field"] == "DS") {
            vcf_import_dosage = true
        }
    }

    return vcf_import_dosage
}

def getFilePaths(row, samplesheet_path) {
    // return a list in order of geno, variants, pheno
    def resolved_path = resolvePath(row.path_prefix, samplesheet_path)
    def suffix = [:]
    def is_vcf = false
    def is_bfile = false
    def is_pfile = false

    switch(row.format) {
        case "pfile":
            suffix = [variants: ".pvar", geno: ".pgen", pheno: ".psam"]
            is_pfile = true
            break
        case "bfile":
            suffix = [variants: ".bim", geno: ".bed", pheno: ".fam"]
            is_bfile = true
            break
        case "vcf":
            suffix = [variants: ".vcf.gz", geno: ".vcf.gz", pheno: ".vcf.gz"]
            is_vcf = true
            break
        default:
            throw new Exception("Invalid format: ${format}")
    }

    variant_paths = suffix.subMap("variants").collect { k, v ->
        try {
            // always prefer zstd compressed data
            f = file(resolved_path + v + ".zst", checkIfExists: true)
        }
        catch (NoSuchFileException exception) {
            f = file(resolved_path + v, checkIfExists: true)
        }
        return [(k): f]
    }.first()

    other_paths = suffix.subMap(["geno", "pheno"]).collect { k, v ->
        [(k) : file(resolved_path + v, checkIfExists:true)]
    }

    // flatten the list of maps
    flat_path_map = other_paths.inject([:], { item, other -> item + other }) + variant_paths

    // call unique to remove duplicate VCF entries
    path_list = [flat_path_map.geno, flat_path_map.variants, flat_path_map.pheno].unique()
    return [path: path_list, is_bfile: is_bfile, is_pfile: is_pfile, is_vcf: is_vcf, format: row.format]
}

def resolvePath(path, samplesheet_path) {
    // isAbsolute() was causing weird issues
    def is_absolute = path.startsWith('/')

    def resolved_path
    if (is_absolute) {
        resolved_path = file(path).resolve()
    } else {
        resolved_path = file(samplesheet_path).getParent().resolve(path)
    }

    return resolved_path
}

def truncateChrom(row) {
    return row.chrom ? row.chrom.toString().replaceFirst("chr", "") : "ALL"
}


def verifySamplesheet(samplesheet) {
    // input must be a file split with headers e.g. splitCsv or splitJSON
    checkChroms(samplesheet)
    checkOneSampleset(samplesheet)
    checkReservedName(samplesheet)
    checkDuplicateChromosomes(samplesheet)

}

def checkChroms(samplesheet) {
    // one missing chromosome (i.e. a combined file) is OK. more than this isn't
    samplesheet.collect{ row -> row.chrom }.map { it ->
        n_empty_chrom = it.count { it == "" }
          if (n_empty_chrom > 1) {
            throw new Exception("${n_empty_chrom} missing chromosomes detected! Maximum is 1. Check your samplesheet.")    
          }
    }    
}

def checkOneSampleset(samplesheet) {
    samplesheet.collect{ row -> row.sampleset }.map { it -> 
        n_samplesets = it.toSet().size() 
          if (n_samplesets > 1) {
            throw new Exception("${n_samplesets} missing chromosomes detected! Maximum is 1. Check your samplesheet.")    
          }
    }    
}

def checkReservedName(samplesheet) {
    samplesheet.collect{ row -> row.sampleset }.map { it -> 
          n_bad_name = it.count { it == "reference" }    

          if (n_bad_name > 0) {
            throw new Exception("Reserved sampleset name detected. Please don't call your sampleset 'reference'")
          }
    }    
}

def checkDuplicateChromosomes(samplesheet) {
    samplesheet.collect{ row -> row.chrom }.map { it ->
          n_unique_chroms = it.toSet().size()
          n_chroms = it.size()

          if (n_unique_chroms != n_chroms) {
             throw new Exception("Duplicated chromosome entries detected in samplesheet")
          }
    }    
}