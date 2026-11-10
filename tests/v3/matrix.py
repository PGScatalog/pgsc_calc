"""Image-based production acceptance checks; run after run.sh in the same /work."""
import csv
import gzip
import hashlib
import math
import os
import shutil
import subprocess
from pathlib import Path


def run(name, sheet='samplesheet', score='raw_score', extra=(), error=None):
    command = ['pgsc_calc_workflow', '-c', '/repo/tests/v3/resources.config',
               '--input', f'/work/fixture/{sheet}.csv', '--scorefile', f'/work/fixture/{score}.txt.gz',
               '--target_build', 'GRCh38', '--outdir', f'/work/results_{name}', '-ansi-log', 'false', *extra]
    result = subprocess.run(command, capture_output=True, text=True)
    output = result.stdout + result.stderr
    Path(f'{name}.log').write_text(output)
    if error:
        assert result.returncode != 0 and error in output, output
    else:
        assert result.returncode == 0, output
        assert Path(f'results_{name}/report.html').stat().st_size > 1000
        assert not list(Path(f'results_{name}').rglob('*.parquet'))
    print(f'PASS: {name}', flush=True)


def scores(directory):
    with gzip.open(Path(directory) / 'scores.txt.gz', 'rt') as handle:
        return sorted(csv.DictReader(handle), key=lambda row: (row['sample_id'], row['accession']))


def compare(directory, expansion=False, summary=True):
    actual = scores(directory)
    expected = scores('results')
    assert len(actual) == len(expected) == 60
    for row, ref in zip(actual, expected, strict=True):
        delta = .3 * (int(row['sample_id'][6:]) % 3) if expansion else 0
        assert row['sample_id'] == ref['sample_id']
        assert math.isclose(float(row['score']), float(ref['score']) + delta, abs_tol=1e-6), row
        assert int(row['n_matched']) == int(ref['n_matched']) + int(expansion)
    if not expansion and summary:
        with open(Path(directory) / 'summary.csv') as handle, open('results/summary.csv') as reference:
            assert sorted(map(str, csv.DictReader(handle))) == sorted(map(str, csv.DictReader(reference)))


def main():
    for name in ('all', 'bgen', 'irrelevant'):
        run(name, sheet=name)
        compare(f'results_{name}')

    archive = Path('results/genotypes.zarr.zip')
    before = hashlib.sha256(archive.read_bytes()).digest()
    cache_args = ['--genotype_cache_zip', str(archive.resolve())]
    run('reuse', extra=cache_args)
    compare('results_reuse')
    run('expanded', score='expanded-score', extra=cache_args)
    compare('results_expanded', expansion=True)
    assert hashlib.sha256(archive.read_bytes()).digest() == before
    assert Path('results_expanded/genotypes.zarr.zip').stat().st_size > archive.stat().st_size

    run('empty', sheet='empty', error='No usable genotype caches')
    run('orphan', sheet='orphan', error='required samples from scoring')
    run('sex', sheet='sex', score='sex-score', extra=['--sex_map', '/work/fixture/sex.tsv'])
    sex_scores = scores('results_sex')
    assert len(sex_scores) == 60 and all(math.isclose(float(row['score']), 5) for row in sex_scores)
    for row in sex_scores:
        assert float(row['allele_count']) == (10 if int(row['sample_id'][6:]) < 30 else 20)
    assert len(list(Path('results_sex/sex_check').rglob('sex_check.tsv'))) == 1
    run('missing_sex', sheet='sex', score='sex-score', error='--sex_map is required')
    run('wrong_sex', sheet='sex', score='sex-score', extra=['--sex_map', '/work/fixture/wrong-sex.tsv'], error='chrX calls contradict their declaration')

    with open('fixture/samplesheet.csv') as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames
        rows = list(reader)
    changed = Path('changed')
    changed.mkdir(exist_ok=True)
    source = Path(rows[0]['path'])
    for path in (source, Path(str(source) + '.csi')):
        shutil.copy2(path, changed / path.name)
    changed_target = changed / source.name
    os.utime(changed_target, ns=(changed_target.stat().st_atime_ns, changed_target.stat().st_mtime_ns + 1000000000))
    rows[0]['path'] = str(changed_target.resolve())
    with open('fixture/changed.csv', 'w') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    run('metadata', sheet='changed', extra=cache_args, error='Cache input metadata mismatch')

    import json
    import zipfile
    unsupported = Path('unsupported.zip')
    with zipfile.ZipFile(archive) as source, zipfile.ZipFile(unsupported, 'w') as target:
        for member in source.infolist():
            data = source.read(member)
            if member.filename.endswith('/zarr.json'):
                metadata = json.loads(data)
                metadata.get('attributes', {}).pop('cache_version', None)
                data = json.dumps(metadata).encode()
            target.writestr(member, data)
    run('unsupported', extra=['--genotype_cache_zip', str(unsupported.resolve())], error='Unsupported cache version. Run without')
    with gzip.open('fixture/raw_score.txt.gz', 'rt') as handle:
        flipped = handle.read().replace('\tC\tA\t', '\tG\tT\t')
    with gzip.open('fixture/flipped-score.txt.gz', 'wt') as handle:
        handle.write(flipped)
    run('flipped', score='flipped-score', extra=['--keep_ambiguous', '--keep_multiallelic'])
    compare('results_flipped', summary=False)
    run('exclude_flipped', score='flipped-score', extra=['--ignore_strand_flips'], error='No scores passed matching threshold')

    run('liftover', score='liftover-score', extra=['--chain_files', '/work/fixture/hg19ToHg38.over.chain.gz'])
    compare('results_liftover')
    run('flags', extra=['--keep_ambiguous', '--keep_multiallelic', '--ignore_strand_flips'])
    compare('results_flags')
    import re
    html = Path('results_flags/report.html').read_text()
    for setting in ('keep_ambiguous', 'keep_multiallelic', 'ignore_strand_flips'):
        assert re.search(setting + r'\s*:\s*true', html), setting
    print('PASS: all production acceptance cases', flush=True)


if __name__ == '__main__':
    main()
