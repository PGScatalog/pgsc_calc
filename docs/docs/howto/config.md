---
sidebar_label: Change default configuration
description: How to set your own configuration
sidebar_position: 5
---

# How to change default configuration

If you want to calculate many polygenic scores for a very large
dataset (e.g. UK Biobank) you will likely need to adjust the pipeline
settings. You might have access to a powerful workstation, a
University cluster, or some cloud compute resources. This section will
show how to set up ``pgsc_calc`` to submit work to these types of
systems by creating and editing [nextflow configuration
files](https://www.nextflow.io/docs/latest/config.html).

## Example: allocate more RAM to loading and scoring processes

```
process {
   withName: PGSC_CALC_LOAD {
       cpus = 2
       memory = "32.GB"
       time = "24.h"
   }
   withName: PGSC_CALC_SCORE {
       cpus = 2
       memory = "32.GB"
       time = "24.h"
   }   
}
```

:::warning

For larger jobs requesting more memory and time can be useful, but allocating more than 2-4 CPUs is rarely helpful.

:::

Save this file as `my_custom_config.config` and include it using Nextflow's `-c` parameter:

```
$ nextflow run pgscatalog/pgsc_calc -r v3-rc1 -c my_custom_config ...
```

## Example: HPC cluster (SLURM)


If you have access to a HPC cluster, you'll need to configure your cluster's
unique parameters to set correct queues, user accounts, and resource
limits.

:::tip

You probably want to use `-profile singularity/apptainer`  on a HPC

:::

```
process {
    executor = 'slurm'
}
```

Nextflow's documentation describes [how to set advanced configuration
for HPCs](https://www.nextflow.io/docs/latest/executor.html#slurm).

:::tip

It's a good idea to submit the [Nextflow process as a job](https://seqera.io/blog/5_tips_for_hpc_users/)

:::