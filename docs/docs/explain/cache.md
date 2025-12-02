---
sidebar_label: The genotypes cache
description: Save time on future calculations by using the cache
sidebar_position: 3
---

# The genotypes cache

## Background

When you run the PGS Catalog Calculator cached variants and genotypes are automatically published to the results directory in a file called `genotypes.zarr.zip`.

For example, if you've previously calculated [PGS001229](https://www.pgscatalog.org/score/PGS001229/) the cache will contain around 51,000 variants.

Polygenic scores for different traits may contain these variants, but with different effect weights assigned. Using the cache means that these variants don't need to be queried on future runs, saving [time and energy 🌳](https://www.green-algorithms.org/)

## Loading process sequence diagram

```mermaid
sequenceDiagram
    PGS Catalog Calculator ->> PGS scoring files: What coordinates are present?
    PGS scoring files ->> PGS Catalog Calculator: Unique coordinates (chromosome / position)
    PGS Catalog Calculator ->> Cache: What positions are missing?
    Cache ->> PGS Catalog Calculator: List of positions not in the cache
    PGS Catalog Calculator ->> Target genome index: Query with uncached coordinates
    Target genome index ->> PGS Catalog Calculator: Genotypes and variants
    PGS Catalog Calculator ->> Cache: Store new genotypes and variants

    Note over Cache: Avoids re-querying genome index on future runs
```

The cache is used to calculate polygenic scores during the scoring process.

:::tip How to use the genotype cache

Check out [the guide on how to use the genotype cache](../howto/cache.md)

:::
