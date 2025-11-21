---
sidebar_label: Use PGS Catalog scoring files
description: How to apply scoring files in the PGS Catalog to your target genomes
sidebar_position: 2
---

# How to use scoring files in the PGS Catalog

The easiest way to calculate a polygenic score is to use a scoring file that's
been published in the [PGS Catalog](https://pgscatalog.org)

## 1. Samplesheet setup

First, set up your samplesheet as [described here](samplesheet.md).

## 2. Pick scores from the PGS Catalog

### Accessions


Individual scores can be used by using Polygenic Score IDs that start
with with the prefix PGS. For example,
[`PGS001229`](http://www.pgscatalog.org/score/PGS001229/). The
parameter ``--pgs_id`` accepts polygenic score IDs:

```
 --pgs_id PGS001229
```

Multiple scores can be set by using a comma separated list:


```
--pgs_id PGS001229,PGS000802
```

### Traits (phenotypes)


If you would like to calculate every polygenic score in the Catalog
for a [trait](https://www.pgscatalog.org/browse/traits/), like
[coronary artery
disease](https://www.pgscatalog.org/trait/EFO_0001645/), then you can
use the ``--efo_id`` parameter:

```
--efo_id EFO_0001645
```

Traits are described using the [Experimental Factor Ontology](https://www.ebi.ac.uk/efo)
(EFO). Multiple traits can be set by using a comma separated list.

### Publications


If you would like to calculate every polygenic score associated with a
[publication](https://www.pgscatalog.org/browse/studies/) in the PGS
Catalog, you can use the ``--pgp_id`` parameter:

```
--pgp_id PGP000001
```

Multiple traits can be set by using a comma separated list.

:::tip

PGS, trait, and publication IDs can be combined to calculate multiple polygenic scores.

:::

# 3. Calculate!

```bash
$ nextflow run pgscatalog/pgscalc \
    -r v3-rc1 \
    -profile <docker/singularity/conda> \    
    --input samplesheet.csv \
    --pgs_id PGS001229 \
    --efo_id EFO_0001645 \
    --pgp_id PGP000001
```