---
sidebar_label: Use your own scoring files
description: How to use your own scoring files with the PGS Catalog Calculator
sidebar_position: 3
---

# How to use a custom scoring file

You might want to use a scoring file that you've developed using different
genomic data, or a scoring file somebody else made that isn't published in the
PGS Catalog.

Custom scoring files need to follow a specific format. The entire process of
using a custom scoring file is described below.

## 1. Samplesheet setup

First, set up your samplesheet as [described here](samplesheet.md).

## 2. Scorefile setup


Setup your scorefile in a spreadsheet by concatenating the variant-information to a
minimal header in the following format:

```
#pgs_name=metaGRS_CAD
#pgs_id=metaGRS_CAD
#trait_reported=Coronary artery disease
#genome_build=GRCh37
```

Variant information should be stored in the following format:

| chr_name | chr_position | effect_allele | other_allele | effect_weight |
|----------|--------------|---------------|--------------|---------------|
| 1        | 2245570      | G             | C            | -2.76009e-02  |
| 8        | 26435271     | T             | C            | 1.95432e-02   |


Save the file as ``scorefile.txt``. The file should be in tab
separated values (TSV) format. Column names are defined in the PGS
Catalog [scoring file format
v2.0](https://www.pgscatalog.org/downloads/#scoring_header) and key
metadata (e.g. ``genome_build`` should be specificied in the header)
to ensure variant matching and/or liftover is consistent with the
target genotyping data.  Scorefiles can be compressed with gzip if you
would like to save storage space (e.g. ``scorefile.txt.gz``).

# 3. Calculate!

Set the path of the custom scoring file with the ``--scorefile`` parameter:

```bash
$ nextflow run pgscatalog/pgscalc \
    -r v3-alpha.1 \
    -profile <docker/singularity/conda> \
    --input samplesheet.csv \
    --scorefile scorefile.txt
```

:::tip

Multiple scoring files can be set using wildcards:

```
--scorefile path/to/scores/score_*.txt
```
:::