# pgscatalog/pgsc_calc: Usage

## Introduction

This pipeline has been set up to simplify calculating polygenic scores for
target genomic data with unknown phenotypes. A polygenic score combines the
effects of many genetic variants into a single number to predict genetic
predisposition for a phenotype. Polygenic scores are typically created by
researchers using genome wide-association study (GWAS) results and large biobank
populations with known phenotypes. These scores are represented by _scoring
files_, which record the weight of hundreds-to-millions of genetic variants,
which can be deposited in the [Polygenic Score
Catalog](https://www.pgscatalog.org/) open database. By applying scoring files
to new target genetic data, it's possible to predict the genetic predisposition
in different populations.

### Genetic data format

...

### Samplesheet format

...

### Scoring file format

...

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run pgscatalog/pgsc_calc --input samplesheet.csv --accession PGS001229 -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below
for more information about profiles.

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code
from GitHub and stores it as a cached version. When running the pipeline after
this, it will always use the cached version if available - even if the pipeline
has been updated since. To make sure that you're running the latest version of
the pipeline, make sure that you regularly update the cached version of the
pipeline:

```bash
nextflow pull pgscatalog/pgsc_calc
```

### Reproducibility

It's a good idea to specify a pipeline version when running the pipeline on your
data. This ensures that a specific version of the pipeline code and software are
used when you run your pipeline. If you keep using the same tag, you'll be
running the same version of the pipeline, even if there have been changes to the
code since.

First, go to the [pgscatalog/pgsc_calc releases
page](https://github.com/PGScatalog/pgsc_calc/releases) and find the latest
version number - numeric only (eg. `0.2`). Then specify this when running the
pipeline with `-r` (one hyphen) - eg. `-r 0.2`.

This version number will be logged in reports when you run the pipeline, so that
you'll know what you used when you look back in the future.

## Core Nextflow arguments

> **NB:** These options are part of Nextflow and use a _single_ hyphen (pipeline
    parameters use a double-hyphen).

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give
configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the
pipeline to use software packaged using different methods (Docker, Singularity,
Podman, Shifter, Charliecloud, Conda) - see below. When using Biocontainers,
most of these software packaging methods pull Docker containers from quay.io e.g
[FastQC](https://quay.io/repository/biocontainers/fastqc) except for Singularity
which directly downloads Singularity images via https hosted by the [Galaxy
project](https://depot.galaxyproject.org/singularity/) and Conda which downloads
and installs software locally from [Bioconda](https://bioconda.github.io/).

> We highly recommend the use of Docker or Singularity containers for full
  pipeline reproducibility, however when this is not possible, Conda is also
  supported.

Some users report problems using Singularity images hosted by the Galaxy project
with older versions of singularity. A workaround is to set the flag
`--singularity_pull_docker_container`. The pipeline also dynamically loads
configurations from
[https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it
runs, making multiple config profiles for various institutional clusters
available at run time. For more information and to see if your system is
available in these configs please see the [nf-core/configs
documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` -
the order of arguments is important!  They are loaded in sequence, so later
profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all
software to be installed and available on the `PATH`. This is _not_ recommended.

* `docker`
    * A generic configuration profile to be used with [Docker](https://docker.com/)
* `singularity`
    * A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
* `podman`
    * A generic configuration profile to be used with [Podman](https://podman.io/)
* `shifter`
    * A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
* `charliecloud`
    * A generic configuration profile to be used with [Charliecloud](https://hpc.github.io/charliecloud/)
* `conda`
    * A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter or Charliecloud.
* `test`
    * A profile with a complete configuration for automated testing
    * Includes links to test data so needs no other parameters

### `-resume`

Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large
amount of memory.  We recommend adding the following line to your environment to
limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

This is more often true in HPC environments, when you're working with a lot of
data. Running large jobs on a login node makes sysadmins sad, so you'll need
some to [take some additional
steps](https://www.nextflow.io/blog/2021/5_tips_for_hpc_users.html) to be
polite.
