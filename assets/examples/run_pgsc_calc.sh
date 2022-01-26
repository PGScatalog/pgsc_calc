#!/bin/sh

# specify the path to main.nf  

nextflow run ../../main.nf -profile docker --input example_data/bfile_samplesheet.csv --scorefile example_data/scorefile.txt

# parameters (starting with two dashes --) can also be set in a JSON or YAML file 
# nextflow run ../../main.nf -profile docker -params-file example_data/params.yaml

# instead of using the main.nf path, use the github repo directly
# nextflow run pgscatalog/pgsc_calc -profile docker --input example_data/bfile_samplesheet.csv --scorefile example_data/scorefile.txt
