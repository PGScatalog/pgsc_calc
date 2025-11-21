---
sidebar_label: Create a samplesheet
description: How to create a samplesheet to use with pgsc_calc
sidebar_position: 1
---

# How to create a samplesheet

A samplesheet describes the structure of your input genotyping
datasets. It's needed because the structure of input data can be very
different across use cases (e.g.  different file formats, directories,
and split vs. unsplit by chromosome).

:::tip

Samplesheets can be in CSV, TSV, JSON, or YAML format

:::

## Simple samplesheet example

A samplesheet can be set up in a spreadsheet program, using the following structure

| sampleset | path                                  | chrom | file_format | genotyping_method | bgen_sample_file                        |
|-----------|---------------------------------------|-------|-------------|-------------------|-----------------------------------------|
| 1000G     | tests/data/bgen/PGS000586_GRCh38.bgen |       | bgen        | array             | tests/data/bgen/PGS000586_GRCh38.sample |


There are five mandatory columns:

- **sampleset**: A text string (no spaces) referring to the name of a
  target dataset of genotyping data containing at least one
  sample/individual. Data from a sampleset may be input as a single
  file, or split across chromosomes into multiple files.  Scores
  generated from files with the same sampleset name are combined in
  later stages of the analysis.

:::warning

- ``pgsc_calc`` works best with cohort data
- Scores calculated for low sample sizes will generate warnings in the
  output report
- You should merge your genomes if they are split per individual before
  using ``pgsc_calc``
  
:::

- **path**: should be set to the path of the target genome file. Absolute paths are preferred.

:::tip

An index must exist in the same directory for all target genome files (e.g. bgi / csi / tbi files)

:::

- **chrom**: An integer (range 1-22) or string (X, Y). If the target genomic
  data file contains multiple chromosomes, leave empty. Don't use a mix of empty
  and integer chromosomes in the same sampleset.

:::note

* X, Y, and MT chromosome support will be added in v3-rc2

:::

- **format**: The file format of the target genomes. Currently supports
  ``bgen`` and ``vcf``.

- **genotyping_method**: How were genotypes called? ``array`` or ``wgs``

:::warning

- Array data should be imputed (e.g. TopMed/Michigan) to increase variant density
- If you use unimputed array data then many scores will probably fail to calculate
- ``wgs`` support will be added in v3-rc2

:::

And one column which is mandatory when format is ``bgen``:

- **bgen_sample_file**: Path to the BGEN sample file, which contains sample identifiers

## Complex samplesheet example

In the example below, each target genome file is split per chromsoome

:::info

* A target genome must contain every sample in a single file
* For example, this means that splitting VCFs into batches of 100,000 samples is not supported (chrom1_batch1, chrom1_batch2, ...)
* This limitation will be removed in a future release candidate

:::

| sampleset | path                                            | chrom | file_format | genotyping_method |
|-----------|-------------------------------------------------|-------|-------------|-------------------|
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_1.vcf.gz  | 1     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_2.vcf.gz  | 2     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_3.vcf.gz  | 3     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_4.vcf.gz  | 4     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_5.vcf.gz  | 5     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_6.vcf.gz  | 6     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_7.vcf.gz  | 7     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_8.vcf.gz  | 8     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_9.vcf.gz  | 9     | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_10.vcf.gz | 10    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_11.vcf.gz | 11    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_12.vcf.gz | 12    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_13.vcf.gz | 13    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_14.vcf.gz | 14    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_15.vcf.gz | 15    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_16.vcf.gz | 16    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_17.vcf.gz | 17    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_18.vcf.gz | 18    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_19.vcf.gz | 19    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_20.vcf.gz | 20    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_21.vcf.gz | 21    | vcf         | array             |
| 1000G     | tests/data/vcf/split/PGS000586_GRCh38_22.vcf.gz | 22    | vcf         | array             |
