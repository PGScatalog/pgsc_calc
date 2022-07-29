#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly tmpdir=$(mktemp -d)


get_ref() {
    # TODO: replace with a wget call
    cp /Users/bwingfield/Documents/projects/testdata/pgsc_calc_1.1.0.db .
}


extract_scores() {
    local db=$1

    sqlite3 $db -Axg "*.txt.gz"
}


extract_genomes() {
    local db=$1

    sqlite3 $db -Axg "*.zst" "*.psam"
}


decompress_genomes() {
    for f in $(ls *.zst)
    do
        out=$(basename $f .zst)
        plink2 --zst-decompress $f > $out
        rm $f
    done
}


update_samplesheet() {
    # don't want sed to modify the header
    head -n 1 tests/scores/samplesheet.csv > tests/scores/samplesheet_annot.csv
    # , instead of / in sed expression avoids escaping all the forward slashes
    # in $tmpdir path, see https://askubuntu.com/a/76842
    tail -n +2  tests/scores/samplesheet.csv | sed 's,chr,'"${tmpdir}"/chr',g' >> tests/scores/samplesheet_annot.csv
    # chr1_phase3 -> /path/to/tmpdir/chr1_phase3
}


main() {
    local db="pgsc_calc_1.1.0.db"

    pushd $tmpdir
    get_ref
    extract_scores $db
    extract_genomes $db
    decompress_genomes
    popd
    update_samplesheet

    echo $tmpdir > tests/scores/score_dir.txt
    echo "Setup complete"
}

main
