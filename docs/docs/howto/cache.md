---
sidebar_label: Reuse cached data
description: How to reuse cached data speed up calculation
sidebar_position: 4
---

# How to reuse cached data

:::info What is the cache?

See here for [more details about what the genotypes cache is.](../explain/cache.md)

:::

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
