import java.nio.file.NoSuchFileException
import java.nio.file.Path
import nextflow.Nextflow

class SamplesheetParser {
    Path path
    Integer n_chrom
    String target_build

    SamplesheetParser(path, n_chro, target_build) {
        this.path = path
        this.n_chrom = n_chrom
        this.target_build = target_build
    }

    def parseCSVRow(row) {
        def parsed_row = [:]
        parsed_row.id = row.sampleset
        parsed_row.n_chrom = this.n_chrom
        parsed_row.chrom = truncateChrom(row)
        parsed_row.format = row.format
        parsed_row.build = this.target_build
        parsed_row.vcf_import_dosage = importDosage(row)
        parsed_row = parsed_row + getFlagMap(row)

        return [parsed_row, getFilePaths(row)]
    }

    def parseJSONRow(row) {
        // note: we don't check for file existence here
        def parsed_row = row.subMap("chrom", "vcf_import_dosage", "n_chrom", "format") 
        parsed_row.id = row.sampleset
        parsed_row = parsed_row + getFlagMap(row)
        parsed_row.build = this.target_build
        parsed_row.chrom = truncateChrom(row)

        return [parsed_row, [row.geno, row.variants, row.pheno]]
    }

    def verifySamplesheet(rows) {
        checkChroms(rows)
        checkOneSampleset(rows)
        checkDuplicateChromosomes(rows)
        checkReservedName(rows)
        return rows
    }

    private def getFlagMap(row) {
        // make a map with some helpful bool flags. useful for both JSON and CSV
        def flags = [:]
        flags.is_vcf = false
        flags.is_bfile = false
        flags.is_pfile = false

        switch (row.format) {
            case "pfile":
                flags.is_pfile = true
                break
            case "bfile":
                flags.is_bfile = true
                break
            case "vcf":
                flags.is_vcf = true
                break
            default:
                Nextflow.error("Invalid format: ${row.format}")
        }
        return flags
    }

    private static def truncateChrom(row) {
        // when plink recodes chromosomes, it drops chr prefix. make sure the samplesheet matches this
        return row.chrom ? row.chrom.toString().replaceFirst("chr", "") : "ALL"
    }

    private def getFilePaths(row) {
        // return a list in order of geno, variants, pheno
        def resolved_path = resolvePath(row.path_prefix)
        def suffix = [:]

        switch (row.format) {
            case "pfile":
                suffix = [variants: ".pvar", geno: ".pgen", pheno: ".psam"]
                break
            case "bfile":
                suffix = [variants: ".bim", geno: ".bed", pheno: ".fam"]
                break
            case "vcf":
                // gzip compression gets picked up later
                suffix = [variants: ".vcf", geno: ".vcf", pheno: ".vcf"]
                break
            default:
                Nextflow.error("Invalid format: ${row.format}")
        }

        // automatically prefer compressed variant information data (and vcfs)
        def variant_path = suffix.subMap("variants").collect { k, v ->
            def f
            try {
                // always prefer zstd compressed data (nobody does this to VCFs... hopefully)
                f = Nextflow.file(resolved_path + v + ".zst", checkIfExists: true)
            }
            catch (NoSuchFileException zst_e) {
                try {
                    // but gzipped is OK too
                    f = Nextflow.file(resolved_path + v + ".gz", checkIfExists: true)
                } catch (NoSuchFileException gzip_e) {
                    // try uncompressed data as last resort
                    f = Nextflow.file(resolved_path + v, checkIfExists: true)
                }
            }
            return f
        }

        def other_paths = suffix.subMap(["geno", "pheno"]).collect { k, v ->
            Nextflow.file(resolved_path + v, checkIfExists: true)
        }

        // call unique to remove duplicate entries for VCFs, adding at index to preserve order
        def path_list = other_paths.plus(1, variant_path).unique()

        return path_list
    }

    private def resolvePath(path) {
        // paths in a CSV samplesheet might be relative, and should be resolved from the samplesheet path
        def is_absolute = path.startsWith('/') // isAbsolute() was causing weird issues

        def resolved_path
        if (is_absolute) {
            resolved_path = Nextflow.file(path).resolve()
        } else {
            resolved_path = Nextflow.file(this.path).getParent().resolve(path)
        }

        return resolved_path
    }

    private static def importDosage(row) {
        // vcf_genotype_field is an optional field in the samplesheet
        def vcf_import_dosage = false
        if (row.containsKey("vcf_genotype_field")) {
            if (row["vcf_genotype_field"] == "DS") {
                vcf_import_dosage = true
            }
        }

        return vcf_import_dosage
    }

    // samplesheet verification methods from here

    private def checkChroms(rows) {
        // one missing chromosome (i.e. a combined file) is OK. more than this isn't
        def chroms = rows.collect { row -> row.chrom }
        def n_empty_chrom = chroms.count { it == "" }
        if (n_empty_chrom > 1) {
            Nextflow.error("${n_empty_chrom} missing chromosomes detected! Maximum is 1. Check your samplesheet.")
        }
    }

    private def checkOneSampleset(rows) {
        def samplesets = rows.collect { row -> row.sampleset }
        def n_samplesets = samplesets.toSet().size()
        if (n_samplesets > 1) {
            Nextflow.error("${n_samplesets} missing chromosomes detected! Maximum is 1. Check your samplesheet.")
        }
    }

    private def checkReservedName(samplesheet) {
        def samplesets = samplesheet.collect { row -> row.sampleset }
        def n_bad_name = samplesets.count { it == "reference" }

        if (n_bad_name != 0) {
            Nextflow.error("Reserved sampleset name detected. Please don't call your sampleset 'reference'")
        }
    }

    private def checkDuplicateChromosomes(samplesheet) {
        def chroms = samplesheet.collect { row -> row.chrom }
        def n_unique_chroms = chroms.toSet().size()
        def n_chroms = chroms.size()

        if (n_unique_chroms != n_chroms) {
            Nextflow.error("Duplicated chromosome entries detected in samplesheet. Check your samplesheet.")
        }
    }

}

