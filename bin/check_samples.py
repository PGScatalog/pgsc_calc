#!/usr/bin/env python3
"""Check empty LOAD outputs cannot silently remove samples from the run."""
import json
import sys
from pathlib import Path


def check_samples(directories):
    required = set()
    retained = set()
    empty = []
    for directory in map(Path, directories):
        manifest = json.loads((directory / 'samples.json').read_text())
        samples = set(manifest['samples'])
        required.update(samples)
        if (directory / 'genotypes.zarr.zip').exists():
            retained.update(samples)
        else:
            empty.append((manifest['shard'], samples))
    if not retained:
        raise ValueError('No usable genotype caches were produced. Check the scoring-file positions, genome build and target inputs.')
    if missing := required - retained:
        shards = ', '.join(shard for shard, samples in empty if samples & missing)
        example = ', '.join(sorted(missing)[:10])
        raise ValueError(f'Empty shards would remove {len(missing)} required samples from scoring: {shards}. Examples: {example}. Check the target inputs and scoring-file positions.')


if __name__ == '__main__':
    check_samples(sys.argv[1:])
