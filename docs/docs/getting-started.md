---
sidebar_position: 2
---


# Get started


``pgsc_calc`` has a few important software dependencies:

* Nextflow
* Docker, Singularity, or Anaconda
* Linux or macOS

Without these dependencies installed you won't be able to run ``pgsc_calc``.

## Step by step setup


1. [Install Nextflow](https://www.nextflow.io/docs/latest/install.html)

```bash
$ java -version # java 17 or later required
$ curl -fsSL get.nextflow.io | bash
$ ./nextflow run hello
```

2. Install one of [Docker](https://www.docker.com/get-started/), [Singularity](https://docs.sylabs.io/guides/latest/user-guide/)/[Apptainer](https://apptainer.org/), or [conda](https://docs.conda.io/projects/conda/en/stable/user-guide/install/index.html)

3. Run the ``pgsc_calc`` test profile:

```
$ nextflow run pgscatalog/pgsc_calc -r v3-alpha.1 -profile test,<docker|singularity|conda>
```

:::info

Please note the test profile genomes are not biologically meaningful,
won't produce valid scores, and aren't compatible with other scores on
the PGS Catalog. We bundle this test data to simplify installation and
automatic tests.

:::

## Calculate your first polygenic scores

If you've completed the setup guide successfully then you're ready to calculate
scores with your genomic data, which are probably genotypes from real
people. Exciting! :dna::test_tube:

## 1. Set up a samplesheet

:::info

* Your target genomes must be indexed VCF/BCF or BGEN files
* Indexes (csi / tbi / bgi files)  must be in the same directory as the target genome file
* Your target genomes should be multi-sample for best calculation efficiency
:::

First, you need to describe the structure of your genomic data in a standardised
way. To do this, set up a spreadsheet that looks like:


| sampleset | path                                    | chrom | file_format | genotyping_method |
|-----------|-----------------------------------------|-------|-------------|-------------------|
| 1000G     | tests/data/bgen/PGS000586_GRCh38.vcf.gz |       | vcf         | array             |


Samplesheets can be in CSV, TSV, JSON, or YAML format.

Samplesheets can describe other ways your data are organised, like genomes split per chromosome or BGEN files. [See here for more details](howto/samplesheet.md). 

## 2. Select scoring files

It's simple to work with polygenic scores that have been published in
the PGS Catalog. You can specify one or more scores using the
`--pgs_id` parameter:

```
--pgs_id PGS001229 # one score
--pgs_id PGS001229,PGS001405 # many scores separated by , (no spaces)
```

:::tip

You can also select scores associated with traits (``--efo_id``) and publications (``--pgp_id``)

:::

If you would like to use your own  scoring file that's not published in the PGS Catalog, [that's OK too](howto/custom.md).


## 3. Set your target genome build

Users are required to specify the genome build that to their genotyping calls are in reference
to using the ``--target_build`` parameter. The ``--target_build`` parameter only supports builds
``GRCh37`` (*hg19*) and ``GRCh38`` (*hg38*).

```
--target_build GRCh38 # ✅
--target_build GRCh37 # ✅
--target_build GRCh36 # ❌ no
```

:::info

* A PGS Catalog score might have been submitted in a different genome build to your target genomes
* The PGS Catalog makes all scoring files available in GRCh37 and GRCh38 by [remapping author-submitted data](https://www.pgscatalog.org/downloads/#hm_pos_fn)
* The pipeline will use the target build parameter to fetch a scoring file that aligns with your target genomes
:::


## 4. Putting it all together

For this example, we'll assume that the input genomes are in build
GRCh38 and you want to use a scoring file in the PGS Catalog:


```
$ nextflow run pgscatalog/pgsc_calc \
  -profile <docker/singularity/apptainer/conda> \
  -r v3-alpha.1 \
  --input samplesheet.csv \
  --target_build GRCh38 \
  --pgs_id PGS001229
```

Congratulations, you've now (hopefully) calculated some scores! 🥳

## Finally

After the workflow executes successfully, the calculated scores and a summary
report should be available in the ``results/`` directory in your current
working directory (``$PWD``) by default.

If you're interested in more information, see the [explanations section](category/explanations)
of the documentation.

:::warning

When interpreting results users should ensure that the samples used for calculation were not used for PGS development (see [Wray et al. (2013)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4096801/)).

:::

## Next steps

* If you're interested in deploying `pgsc_calc` on population-scale biobanks like [UK Biobank](https://www.ukbiobank.ac.uk/) or [All of Us](https://allofus.nih.gov/), please see the [tutorials section](category/tutorials)
* Many common use cases are described in the [how-to section](category/how-to-guides)
* If you have any questions, please see our [discussion forum](https://github.com/pgscatalog/pgsc_calc/discussions)
* If you experience any problems that you can't fix after checking this documentation, please [open an issue](https://github.com/pgscatalog/pgsc_calc/issues)

Good luck!