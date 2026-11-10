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
            for pos in (100, 200, 300):
                record = out.new_record(contig=chrom, start=pos - 1, alleles=('A', 'C'))
                for i in range(batch * 30, (batch + 1) * 30):
                    gt = ((0, 0), (0, 1), (1, 1))[i % 3]
                    if chrom == '1' and pos == 100 and batch == 0:
                        gt = (None, None)
                    record.samples[f'sample{i:02}']['GT'] = gt
                out.write(record)
        pysam.bcftools.index(str(path))
        rows.append(['prototype', chrom, str(path.resolve()), 'vcf', 'array', 'unobserved'])
with open(root / 'samplesheet.csv', 'w') as handle:
    writer = csv.writer(handle)
    writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method', 'absent_variants'])
    writer.writerows(rows)
with gzip.open(root / 'score.txt.gz', 'wt') as handle:
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\teffect_type\tis_duplicated\taccession\trow_nr\n')
    for row, (chrom, pos, weight) in enumerate([('1', 100, .1), ('1', 200, .2), ('2', 100, .1), ('2', 200, .2)]):
        handle.write(f'{chrom}\t{pos}\tC\tA\t{weight}\tadditive\tFalse\tPGS999999\t{row}\n')
print('Prepared 60 samples, 2 chromosomes and 2 sample batches (4 shards).')

with gzip.open(root / 'raw_score.txt.gz', 'wt') as handle:
    handle.write('#pgs_id=PGS999999\n#genome_build=GRCh38\n#variants_number=4\n#trait_reported=synthetic\n')
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\n')
    for chrom, pos, weight in [('1', 100, .1), ('1', 200, .2), ('2', 100, .1), ('2', 200, .2)]:
        handle.write(f'{chrom}\t{pos}\tC\tA\t{weight}\n')

# Unsplit input preserves the same calls and sample IDs as the rectangular shards.
header = pysam.VariantHeader()
for chrom in ('1', '2'):
    header.contigs.add(chrom, length=10000)
header.formats.add('GT', 1, 'String', 'Genotype')
for i in range(60):
    header.add_sample(f'sample{i:02}')
path = root / 'all.vcf.gz'
with pysam.VariantFile(path, 'wz', header=header) as out:
    for chrom in ('1', '2'):
        for pos in (100, 200, 300):
            record = out.new_record(contig=chrom, start=pos - 1, alleles=('A', 'C'))
            for i in range(60):
                gt = ((0, 0), (0, 1), (1, 1))[i % 3]
                if chrom == '1' and pos == 100 and i < 30:
                    gt = (None, None)
                record.samples[f'sample{i:02}']['GT'] = gt
            out.write(record)
pysam.bcftools.index(str(path))
with open(root / 'all.csv', 'w') as handle:
    writer = csv.writer(handle)
    writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method'])
    writer.writerow(['prototype', '', str(path.resolve()), 'vcf', 'array'])

# BGEN with deterministic diploid probabilities, including the same missing calls.
import numpy as np
import subprocess
from bgen import BgenWriter
samples = [f'sample{i:02}' for i in range(60)]
path = root / 'all.bgen'
with BgenWriter(path, n_samples=60, samples=samples) as out:
    for chrom in ('1', '2'):
        for pos in (100, 200, 300):
            probs = np.eye(3)[np.arange(60) % 3]
            if chrom == '1' and pos == 100:
                probs[:30] = np.nan
            out.add_variant(varid=f'{chrom}:{pos}', rsid=f'{chrom}:{pos}', chrom=chrom,
                            pos=pos, alleles=['A', 'C'], genotypes=probs,
                            ploidy=np.full(60, 2, dtype=np.uint8), phased=False, bit_depth=8)
subprocess.run(['bgenix', '-index', '-clobber', '-g', str(path)], check=True)
sample_path = root / 'all.sample'
sample_path.write_text('ID_1 ID_2 missing\n0 0 0\n' + ''.join(f'{s} {s} 0\n' for s in samples))
with open(root / 'bgen.csv', 'w') as handle:
    writer = csv.writer(handle)
    writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method', 'bgen_sample_file'])
    writer.writerow(['prototype', 'ALL', str(path.resolve()), 'bgen', 'array', str(sample_path.resolve())])

for name, samples in [('irrelevant', ['sample00']), ('orphan', ['missing_sample'])]:
    header = pysam.VariantHeader()
    header.contigs.add('3', length=10000)
    header.formats.add('GT', 1, 'String', 'Genotype')
    for sample in samples:
        header.add_sample(sample)
    path = root / f'{name}.vcf.gz'
    with pysam.VariantFile(path, 'wz', header=header) as out:
        record = out.new_record(contig='3', start=99, alleles=('A', 'C'))
        for sample in samples:
            record.samples[sample]['GT'] = (0, 1)
        out.write(record)
    pysam.bcftools.index(str(path))
    with open(root / f'{name}.csv', 'w') as handle:
        writer = csv.writer(handle)
        writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method', 'absent_variants'])
        writer.writerows(rows + [['prototype', '3', str(path.resolve()), 'vcf', 'array', 'unobserved']])
    if name == 'orphan':
        with open(root / 'empty.csv', 'w') as handle:
            writer = csv.writer(handle)
            writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method'])
            writer.writerow(['prototype', '3', str(path.resolve()), 'vcf', 'array'])

header = pysam.VariantHeader()
header.contigs.add('X', length=10000)
header.formats.add('GT', 1, 'String', 'Genotype')
samples = [f'sample{i:02}' for i in range(60)]
for sample in samples:
    header.add_sample(sample)
path = root / 'chrX.vcf.gz'
with pysam.VariantFile(path, 'wz', header=header) as out:
    for pos in range(100, 110):
        record = out.new_record(contig='X', start=pos - 1, alleles=('A', 'C'))
        for i, sample in enumerate(samples):
            record.samples[sample]['GT'] = (1,) if i < 30 else (0, 1)
        out.write(record)
pysam.bcftools.index(str(path))
with open(root / 'sex.csv', 'w') as handle:
    writer = csv.writer(handle)
    writer.writerow(['sampleset', 'chrom', 'path', 'file_format', 'genotyping_method'])
    writer.writerow(['prototype', 'chrX', str(path.resolve()), 'vcf', 'array'])
(root / 'sex.tsv').write_text('sample_id\tsex\n' + ''.join(f'{s}\t{1 if i < 30 else 2}\n' for i, s in enumerate(samples)))
(root / 'wrong-sex.tsv').write_text('sample_id\tsex\n' + ''.join(f'{s}\t2\n' for s in samples))
with gzip.open(root / 'sex-score.txt.gz', 'wt') as handle:
    handle.write('#pgs_id=PGS999998\n#genome_build=GRCh38\n#variants_number=10\n#trait_reported=synthetic\n')
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\n')
    for pos in range(100, 110):
        handle.write(f'X\t{pos}\tC\tA\t0.5\n')

with gzip.open(root / 'expanded-score.txt.gz', 'wt') as handle:
    handle.write('#pgs_id=PGS999999\n#genome_build=GRCh38\n#variants_number=5\n#trait_reported=synthetic\n')
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\n')
    for chrom, pos, weight in [('1', 100, .1), ('1', 200, .2), ('2', 100, .1), ('2', 200, .2), ('1', 300, .3)]:
        handle.write(f'{chrom}\t{pos}\tC\tA\t{weight}\n')

with gzip.open(root / 'hg19ToHg38.over.chain.gz', 'wt') as handle:
    for chrom in ('1', '2'):
        handle.write(f'chain 1000 chr{chrom} 10000 + 0 900 chr{chrom} 10000 + 10 910 {chrom}\n900\n\n')
with gzip.open(root / 'liftover-score.txt.gz', 'wt') as handle:
    handle.write('#pgs_id=PGS999999\n#genome_build=GRCh37\n#variants_number=4\n#trait_reported=synthetic\n')
    handle.write('chr_name\tchr_position\teffect_allele\tother_allele\teffect_weight\n')
    for chrom, pos, weight in [('1', 90, .1), ('1', 190, .2), ('2', 90, .1), ('2', 190, .2)]:
        handle.write(f'{chrom}\t{pos}\tC\tA\t{weight}\n')
