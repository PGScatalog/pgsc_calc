---
sidebar_label: Reuse cached data
description: How to reuse cached data speed up calculation
sidebar_position: 4
---

# How to reuse cached data

## Background

When you run the PGS Catalog Calculator cached variants and genotypes are automatically published to the results directory in a file called `genotypes.zarr.zip`.

For example, if you've previously calculated [PGS001229](https://www.pgscatalog.org/score/PGS001229/) the cache will contain around 51,000 variants.

Polygenic scores for different traits may contain these variants, but with different effect weights assigned. Using the cache means that these variants don't need to be queried on future runs, saving [time and energy 🌳](https://www.green-algorithms.org/)

## Reusing the cache

Just add the `--genotype_cache_zip` parameter after you've calculated a score for the first time:


```
$ nextflow run pgscatalog/pgsc_calc \
  -r v3-rc1 \
  --input samplesheet.csv \
  --target_build GRCh38 \
  --genotype_cache_zip <PATH/TO/genotypes.zarr.zip>
```

This can significantly speed up the `PGSC_CALC_LOAD` processes depending on the number of successful cache hits.

When the calculation job finishes a new cache will be published in the results directory, containing previously uncached variants.

:::tip

The cache is compressed but can grow to be quite large. If you want to disable creating and publishing the cache add a parameter to your run:

 `--publish_cache false`

:::
