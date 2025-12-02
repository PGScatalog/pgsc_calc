---
sidebar_label: All of Us deployment
description: How to calculate polygenic scores on the All of Us cohort
---

# All of Us Researcher Workbench tutorial

This tutorial describes how to calculate [PGS000018](https://www.pgscatalog.org/score/PGS000018/), a polygenic score (PGS) 
which measures coronary artery disease risk.

The simplest way to work with the All of Us data is to use a run [nextflow in a terminal](https://support.researchallofus.org/hc/en-us/articles/4811899197076-Workflows-in-the-All-of-Us-Researcher-Workbench-Nextflow-and-Cromwell), 
which works like a local Linux machine.

By the end of this tutorial you should understand how to use the PGS Catalog Calculator to calculate PGS in the All of Us cohort.

## Before you get started

You'll need:
* [Approval to access](https://www.researchallofus.org/register/) All of Us data.
* A project with access to [Controlled Tier](https://www.researchallofus.org/data-tools/data-access/) data (contains genotypes) in the Researcher Workbench.

## 1. Install `nextflow` & `conda`

### Install `nextflow`

First, follow the official [instructions for how to install nextflow](https://workbench.researchallofus.org/workspaces/aou-rw-5b81a011/howtousenextflowintheresearcherworkbenchv7/data?_gl=1*1hxzxb7*_ga*MjgzMTM4MzgyLjE3MzM5MjQxOTQ.*_ga_K8QTQT89XP*czE3NjQ2MDc4OTgkbzIwJGcxJHQxNzY0NjA4ODg1JGoyOSRsMCRoMA).

### Install `conda`

The version of java in the workbench is slightly outdated for newer versions of nextflow. The first step of the tutorial
is to open a terminal, and [install conda (official AoU docs)](https://support.researchallofus.org/hc/en-us/articles/31335822037524-How-to-install-Miniconda-Anaconda-in-the-Researcher-Workbench):

```bash
# Create the directory ~/miniconda3 if it does not already exist
$ mkdir -p ~/miniconda3

# Download the latest Miniconda3 installer for Linux x86_64 architecture
# and save it as ~/miniconda3/miniconda.sh
$ wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh

# Run the Miniconda3 installer script in batch mode (-b), update the installation (-u),
# and specify the installation path as ~/miniconda3 (-p ~/miniconda3)
$ bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3

# Remove the Miniconda3 installer script after the installation is complete
$ rm ~/miniconda3/miniconda.sh

# initialization:
$ ~/miniconda3/bin/conda init bash

# use immediately in the current shell session
$ source ~/.bashrc

# check conda environments
$ conda info --env
# Locate the path to the conda executable
$ which conda
```

Once you have sucessfully installed conda, you can create & activate an environment:
```bash
# create conda environment
$ conda create -n enxf python=3.12 -y

# activate environment
$ conda activate enxf

# install more recent java version
(enxf) $ conda install -c conda-forge openjdk=17

# check that java is installed
(enxf) $ java -version
openjdk version "17.0.3-internal" 2022-04-19
OpenJDK Runtime Environment (build 17.0.3-internal+0-adhoc..src)
OpenJDK 64-Bit Server VM (build 17.0.3-internal+0-adhoc..src, mixed mode, sharing)

# check that nextflow works
(enxf) $ nextflow run hello
Hello world!

Hola world!

Ciao world!

Bonjour world!
```
## 2. Get ready to run `pgsc_calc`

### 2.1 Create a configuration file

To make a [configuration file](../howto/config.md) for `pgsc_calc`, we will append pipeline-specific settings to the standard nextflow config
file (` ~/.nextflow/config`) provided by All of Us. These settings are customised to work well with very large scale data, 
and have been tested on runs with multiple large PGS. 

```bash
(enxf) $ echo "process {
    withName: 'PGSC_CALC_FORMAT' {
        cpus = 2
        memory = { 10.GB * task.attempt }
    }
    withName: 'PGSC_CALC_LOAD' {
        cpus = 1
        memory = { 40.GB * task.attempt }
    }
    withName: 'PGSC_CALC_SCORE' {
        cpus = 4
        memory = { 80.GB * task.attempt }
    }
}
params {
    variant_batch_size = 1000
}
" | cat ~/.nextflow/config - > v3_config.txt
```

:::tip

`variant_batch_size` controls the number of variants processed at a time (it's the size of each [Zarr array chunk](https://zarr.readthedocs.io/en/stable/quick-start/)). 
Larger chunk sizes will use more RAM but may improve performance when calculating very large scores containing millions of variants.

:::

### 2.2 Prepare a samplesheet

This will set up a [samplesheet](../howto/samplesheet.md) for numeric chromosomes the [Allele Count/Allele Frequency (ACAF) threshold callset](https://support.researchallofus.org/hc/en-us/articles/14929793660948-Smaller-Callsets-for-Analyzing-Short-Read-WGS-SNP-Indel-Data-with-Hail-MT-VCF-and-PLINK) in JSON format:

```bash
(enxf) $ for i in {1..22}; do
  echo "gs://fc-aou-datasets-controlled/v8/wgs/short_read/snpindel/acaf_threshold/bgen/chr${i}.bgen"
done | awk -v OFS="," '
BEGIN { ORS = ""; print " [ "}
{
    full = $0
    # extract chromosome number
    chrom = ""
    if (match(full, /chr[0-9]+/)) {
        chrom = substr(full, RSTART+3, RLENGTH-3)
    }
    # get .sample path
    sample = full
    sub(/\.[^.\/]+$/, ".sample", sample)
    printf "%s{\"sampleset\": \"%s\", \"path\": \"%s\", \"chrom\": \"%s\",  \"file_format\": \"%s\",  \"genotyping_method\": \"%s\",  \"bgen_sample_file\": \"%s\"}",
        separator, "ukbtopmed", full, chrom, "bgen", "array", sample
        separator=", "
}
END { print " ] " }
' | jq > acaf_samplesheet.json
```