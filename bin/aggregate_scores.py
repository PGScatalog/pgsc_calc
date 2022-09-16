#!/usr/bin/env python3

import glob
import pandas as pd

scorefiles = glob.glob("*.sscore")

def select_agg_cols(cols):
    keep_cols = ['DENOM']
    return [x for x in cols if (x.endswith('_SUM') and (x != 'NAMED_ALLELE_DOSAGE_SUM')) or (x in keep_cols)]

aggcols = set()

for i, path in enumerate(scorefiles):
    # Read Current DF
    print(i, 'Reading:', path)
    df = pd.read_table(path)

    # Set index [sampleset, IID]
    df = df.assign(sampleset=path.split('_')[0]).set_index(['sampleset', '#IID'])
    df.index.names = ['sampleset', 'IID']

    # Subset to aggregatable columns
    df = df[select_agg_cols(df.columns)]
    aggcols = aggcols.union(list(df.columns))

    # Combine DFs
    if i == 0:
        print('Intializing combined DF')
        combined = df.copy()
    else:
        print('Adding to combined DF')
        combined = combined.add(df, fill_value=0)

assert all([x in combined.columns for x in aggcols]), "All Aggregatable Columns are present in the final DF"

# Calculate _AVG
print('Averging Data')
avgs = combined.loc[:,combined.columns.str.endswith('_SUM')].divide(combined['DENOM'], axis=0)
avgs.columns = avgs.columns.str.replace('_SUM', '_AVG')
combined = pd.concat([combined, avgs], axis=1)

# Print _AVG
print('Writing Aggregated Data')
combined.to_csv('aggregated_scores.txt.gz', sep='\t', compression='gzip')
