"""Check the prototype result against serial scoring and simple arithmetic."""
import csv
import gzip
import math
from pathlib import Path


def read(path):
    with gzip.open(path, 'rt') as handle:
        return sorted(csv.DictReader(handle), key=lambda row: row['sample_id'])

actual = read('results/scores.txt.gz')
serial = read('serial-scores.txt.gz')
assert len(actual) == len(serial) == 60
for a, b in zip(actual, serial, strict=True):
    for field in a:
        if field in ('score', 'dosage_sum', 'score_avg'):
            assert math.isclose(float(a[field]), float(b[field]), abs_tol=1e-6), (field, a, b)
        else:
            assert a[field] == b[field], (field, a, b)
    i = int(a['sample_id'].removeprefix('sample'))
    expected = .1 + .5 * (i % 3) if i < 30 else .6 * (i % 3)
    assert math.isclose(float(a['score']), expected, abs_tol=1e-6), a
    assert int(a['n_matched']) == 4, a
    assert float(a['allele_count']) == (6 if i < 30 else 8), a
assert not list(Path('results').rglob('*.parquet'))
print('PASS: all 60 samples match serial scores and expected pooled-imputation arithmetic.')
