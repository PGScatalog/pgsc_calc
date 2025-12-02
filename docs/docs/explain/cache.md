---
sidebar_label: The genotypes cache
description: Save time on future calculations by using the cache
sidebar_position: 3
---

# The genotypes cache

## What the cache is helpful for ✅

* Many variants occur across multiple scoring files PGS scoring files [(like HapMap3)](https://doi.org/10.1371/journal.pgen.1009021), although they have different weights associated with each effect allele
* The cache can speed up repeated calculations of **different PGS on the same set of files** by skipping both redundant index queries and parsing previously seen variants
* The speed up affects the `PGSC_CALC LOAD` processes, helping to save [time and energy 🌳](https://www.green-algorithms.org/)

## What the cache doesn't help ❌

* If you use case is to calculate one PGS on many different target genomes, the cache will:
    * not provide any speedup
    * waste storage space on your computer
* In this case it can be better to set `--publish_cache false`

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

The cache is then used during the `PGSC_CALC SCORE` process.

:::tip How to use the genotype cache

Check out [the guide on how to use the genotype cache](../howto/cache.md)

:::
