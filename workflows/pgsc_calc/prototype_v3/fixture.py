"""Generate disposable synthetic input inside the test image."""
import csv
import gzip
from pathlib import Path

import pysam
import pysam.bcftools

root = Path('fixture')
root.mkdir(exist_ok=True)
rows = []
for chrom in ('1', '2'):
    for batch in range(2):
        path = root / f'chr{chrom}.batch{batch}.vcf.gz'
        header = pysam.VariantHeader()
        header.contigs.add(chrom, length=10000)
        header.formats.add('GT', 1, 'String', 'Genotype')
        for i in range(batch * 30, (batch + 1) * 30):
            header.add_sample(f'sample{i:02}')
        with pysam.VariantFile(path, 'wz', header=header) as out:
            for pos in (100, 200):
                record = out.new_record(contig=chrom, start=pos - 1, alleles=('A', 'C'))
                for i in range(batch * 30, (batch + 1) * 30):
                    gt = ((0, 0), (0, 1), (1, 1))[i % 3]
                    if chrom == '1' and pos == 100 and batch == 0:
                        # A partial call retains the site through bcftools --exclude-uncalled,
                        # but contributes no allele counts under whole-call missingness.
                        gt = (0, None) if i == 0 else (None, None)
                    record.samples[f'sample{i:02}']['GT'] = gt
                out.write(record)
        pysam.bcftools.index(str(path))
        rows.append(['prototype', chrom, str(path.resolve()), 'vcf', 'unobserved'])
with open(root / 'samplesheet.csv', 'w') as handle:
    writer = csv.writer(handle)
    writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'absent_variants'])
    writer.writerows(rows)
with gzip.open(root / 'score.txt.gz', 'wt') as handle:
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\teffect_type\tis_duplicated\taccession\trow_nr\n')
    for row, (chrom, pos, weight) in enumerate([('1', 100, .1), ('1', 200, .2), ('2', 100, .1), ('2', 200, .2)]):
        handle.write(f'{chrom}\t{pos}\tC\tA\t{weight}\tadditive\tFalse\tPGS999999\t{row}\n')
print('Prepared 60 samples, 2 chromosomes and 2 sample batches (4 shards).')
