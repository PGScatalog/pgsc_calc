"""Run inside the image after fixture.py; invalid declarations must start no tasks."""
import csv
import subprocess
from pathlib import Path

with open('fixture/samplesheet.csv') as handle:
    reader = csv.DictReader(handle)
    fields = reader.fieldnames
    original = list(reader)

cases = []
rows = [dict(row) for row in original]
rows[0]['sampleset'] = 'another'
cases.append(('samplesets', rows, 'Exactly one sampleset'))
rows = [dict(row) for row in original]
rows.append(dict(rows[0], chrom='chr01'))
cases.append(('duplicate', rows, 'Duplicate cache leaf'))
rows = [dict(row) for row in original]
rows[0]['absent_variants'] = 'homref'
cases.append(('conflicting', rows, 'Conflicting absent_variants'))
rows = [dict(row, absent_variants='homref') for row in original]
cases.append(('homref', rows, 'Only absent_variants=unobserved'))

for chrom in ('0', '27'):
    rows = [dict(row) for row in original]
    rows[0]['chrom'] = chrom
    cases.append((f'chrom-{chrom}', rows, 'chrom'))

for name, rows, message in cases:
    path = Path(f'fixture/reject-{name}.csv')
    with path.open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    command = ['pgsc_calc_workflow',
               '--input', str(path.resolve()), '--scorefile', '/work/fixture/raw_score.txt.gz',
               '--target_build', 'GRCh38', '--outdir', f'/work/reject-{name}', '-ansi-log', 'false']
    result = subprocess.run(command, capture_output=True, text=True)
    output = result.stdout + result.stderr
    assert result.returncode != 0 and message in output and 'Submitted process' not in output, output
    print(f'PASS: {name} rejected before processing')

base = ['pgsc_calc_workflow', '--input', '/work/fixture/samplesheet.csv',
        '--scorefile', '/work/fixture/raw_score.txt.gz', '--target_build', 'GRCh38', '-ansi-log', 'false']
for name, args, message in [
    ('overwrite-cache', ['--outdir', '/work/results', '--genotype_cache_zip', '/work/results/genotypes.zarr.zip'], 'Publication must not overwrite'),
    ('catalog-offline', ['--pgs_id', 'PGS000001'], 'Catalog downloads are disabled offline'),
    ('remote-offline', ['--sex_map', 'https://example.org/sex.tsv'], 'Offline execution requires local input files'),
]:
    result = subprocess.run(base + args, capture_output=True, text=True)
    output = result.stdout + result.stderr
    assert result.returncode != 0 and message in output and 'Submitted process' not in output, output
    print(f'PASS: {name} rejected before processing', flush=True)
