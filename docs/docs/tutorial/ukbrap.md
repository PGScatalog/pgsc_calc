---
sidebar_label: UK Biobank deployment
description: How to calculate polygenic scores on the UK Biobank Research Analysis Platform
---

# UK Biobank Research Analysis Platform tutorial

The simplest way to work with the UK Biobank Research Analysis Platform (RAP) is to use the [Cloud Workstation](https://documentation.dnanexus.com/developer/cloud-workstation), which works like a local Linux machine.

This tutorial describes how to calculate [PGS000010](https://www.pgscatalog.org/score/PGS000010/), a polygenic score which measures coronary artery disease risk, for ~500,000 people in UK Biobank.

By the end of this tutorial you should understand how to use the PGS Catalog Calculator to calculate polygenic scores on the UK Biobank RAP.

:::danger

* Many scores in the PGS Catalog were developed using UK Biobank data
* Users should take note of whether the input samples were used in the development of the PGS being scored as this can lead to inflated estimate of PGS performance (see [Wray etal. (2013)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4096801/) for discussion)
* PGS000010 was not developed on UK Biobank (check the [cohort tab](https://www.pgscatalog.org/score/PGS000010/) for development samples)
* See [PGS001229](https://www.pgscatalog.org/score/PGS001229/) for an example of a score that was developed using UK Biobank data

:::

## Before you get started

You'll need:

* Access to the [UK Biobank](https://www.ukbiobank.ac.uk/about-us/how-we-work/access-to-uk-biobank-data/) and [Research Analysis Platform](https://www.ukbiobank.ac.uk/use-our-data/research-analysis-platform/)
* A UK Biobank project with access to imputed genetic genotypes
* The [DNAnexus Platform SDK toolkit installed and set up](https://documentation.dnanexus.com/downloads) on your computer


## 1. Start a cloud workstation instance

```bash
$ dx run cloud_workstation -imax_session_length=1h --allow-ssh --instance-type "mem3_ssd1_v2_x8" --priority "high"
...
Job ID: job-XXXXXX
$ dx ssh ${JOB_ID}
```

:::tip

* High priority is good for interactive work. You can save money by changing priority to low/medium for batch jobs.

:::

## 2. Set up `dxfuse`

The imputed genotypes are quite large (~3TB). Instead of downloading this data to the cloud workstation, you can mount your project data using a [FUSE filesystem](https://github.com/dnanexus/dxfuse).

```bash
$ wget https://github.com/dnanexus/dxfuse/releases/download/v1.6.1/dxfuse-linux
$ chmod +x dxfuse-linux
$ mkdir mount
$ ./dxfuse-linux mount ${PROJECT_NAME}
$ ls ${HOME}/mount/${PROJECT_NAME} # your files should appear here
```

You should now have read only access to your project data, including imputed genotypes.

## 3. Set up Nextflow

```bash
$ sudo apt-get update && sudo apt-get install -y default-jre
$ curl -s https://get.nextflow.io | bash
$ sudo mv nextflow /usr/local/bin
$ nextflow run hello
...
Ciao world!

Hello world!

Hola world!
```

## 4. Set up `pgsc_calc`

```bash
$ git clone -b v3-rc1 https://github.com/PGScatalog/pgsc_calc.git
$ cd pgsc_calc
$ nextflow run main.nf -profile test_full,docker
...
[bb/219a0e] process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_FORMAT ([PGS000586_hmPOS_GRCh38.txt.gz])                                     [100%] 1 of 1 ✔
[fd/3b3a3e] process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_LOAD ([sampleset:1000G, chrom:21, file_format:vcf, genotyping_method:array]) [100%] 22 of 22 ✔
[3e/d0a70f] process > PGSCATALOG_PGSC_CALC:PGSC_CALC:PGSC_CALC_SCORE                                                                        [100%] 1 of 1 ✔
- [pgscatalog/pgsc_calc] Pipeline completed successfully -
```

## 5. Create a configuration file

This [configuration file](../howto/config.md) is customised to work well with very large scale data, like UK Biobank. It's been tested on [PGS000010](https://www.pgscatalog.org/score/PGS000010/) and [PGS001229](https://www.pgscatalog.org/score/PGS001229/).

```bash
$ echo "process {
    withName: 'PGSC_CALC_FORMAT' {
        cpus = 2
        memory = { 10.GB * task.attempt }
    }
    withName: 'PGSC_CALC_LOAD' {
        cpus = 1
        memory = { 16.GB * task.attempt }
    }
    withName: 'PGSC_CALC_SCORE' {
        cpus = 4
        memory = { 60.GB * task.attempt }
    }
}
params {
    variant_batch_size = 1000
}
" > ${HOME}/ukb_config.config
```

:::tip

`variant_batch_size` controls the number of variants processed at a time (it's the size of each [Zarr array chunk](https://zarr.readthedocs.io/en/stable/quick-start/)). Larger chunk sizes will use more RAM but may improve performance when calculating very large scores containing millions of variants.

:::

## 6. Prepare a samplesheet

This will set up a [samplesheet](../howto/samplesheet.md) for numeric chromosomes for [TopMed imputed data](https://biobank.ndph.ox.ac.uk/ukb/field.cgi?id=21007) in JSON format:

```bash
$ find "${HOME}/mount/${PROJECT_NAME}/Bulk/Imputation/Imputation from genotype (TOPmed)" -regex '.*c[0-9]+.*.bgen' \
  | awk -v OFS="," '
BEGIN { ORS = ""; print " [ "}
{
    full = $0

    # extract number after "c"
    chrom = ""
    if (match(full, /c[0-9]+/)) {
        chrom = substr(full, RSTART+1, RLENGTH-1)
    }

    # get .sample path
    sample = full
    sub(/\.[^.\/]+$/, ".sample", sample)

    printf "%s{\"sampleset\": \"%s\", \"path\": \"%s\", \"chrom\": \"%s\",  \"file_format\": \"%s\",  \"genotyping_method\": \"%s\",  \"bgen_sample_file\": \"%s\"}",
        separator, "ukbtopmed", full, chrom, "bgen", "array", sample
        separator=", "
}
END { print " ] " }
' | jq > ${HOME}/samplesheet.json
```

## 7. (Optional) Snapshot your system

* Your cloud workstation is now ready to calculate polygenic scores
* You might want to save the state of your cloud workstation using [`dx-create-snapshot`](https://academy.dnanexus.com/interactivecloudcomputing/cloudworkstation#snapshot)
* When you create new cloud workstations you can load this snapshot to save time

```bash
$ sudo umount ${HOME}/mount
$ dx-create-snapshot
```

* When restoring the snapshot, remember to remount the file system with `dxfuse`

## 8. Run `pgsc_calc`

```bash
$ cd ${HOME}/pgsc_calc
$ nextflow run main.nf \
  -profile docker \
  --input $HOME/samplesheet.json \
  --target_build GRCh38 \
  -c $HOME/ukb_config.config \
  --outdir $HOME/results \
  --pgs_id PGS000010
```

:::tip

After the calculation finishes don't forget to [save the results directory to your project storage](https://documentation.dnanexus.com/developer/cloud-workstation#saving-files) and terminate the cloud workstation job.

:::

## Next steps

* `dxfuse` works well for smaller scores, which contain hundreds or thousands of variants. For more complex jobs, which can contain millions of variants, consider downloading the genotype data to your cloud workstation to significantly speed up calculation.
* Consider using [larger instance types](https://documentation.dnanexus.com/developer/api/running-analyses/instance-types#standard-aws-instance-types) so more processes can run in parallel on your local machine.
* Consider saving the [genotype cache to your project workspace to save time on future calculation jobs](../howto/cache.md).