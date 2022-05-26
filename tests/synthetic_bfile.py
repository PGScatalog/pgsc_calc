#!/usr/bin/env python

# write a synthetic plink bfile and check scoring with it

import pandas as pd
import binascii

# bim file =====================================================================
d = {'chr': [1, 1], 'id': ['protec', 'attac'], 'cm': [0, 0], 'pos': [3, 4], \
     'ref': ['A', 'C'], 'alt': ['G', 'A'] }
bim = pd.DataFrame(d)
bim.to_csv('test.bim', index = False, header = None, sep = '\t')

# score file ===================================================================
scorefile = bim[['id', 'ref']].assign(effect_weight = [0.5, -2.2])
scorefile.to_csv('test.scores', index = False, header = None, sep = '\t')

# fam file =====================================================================
# 6 people: alice, bob, dingus, doofus, blarp, and darp
# 54 random IDs
f = {'FID': ['dummy']*6, 'IID': ['alice', 'bob', 'dingus', 'doofus', 'blarp', 'darp'],
     'F': [0]*6, 'M': [0]*6, 'sex': [0]*6, 'pheno': [0]*6 }
fam = pd.concat([pd.DataFrame(f)]*10)
people = pd.Series(fam['IID'][:6].to_list() + ['p' + str(i) for i in range(6, fam.shape[0])])
fam['IID'] = people.values

fam.to_csv('test.fam', index = False, header = None, sep = '\t')

# bed file =====================================================================

magic_numbers = ['6c', '1b', '01']

# V blocks of N/4 (rounded up) bytes
# V = n variants (2)
# N = n_samples (60)
# Sequence of 60 / 4 = 15 byte blocks, one per variant (30 byte blocks total)
# alice and bob are homozygous first allele
# dingus and doofus are heterozygous
# blarp and darp are homozygous second allele
# others are homozygous second allele

# first block ------------------ second block -------------------
# 10     | 10     | 00  | 00    | 11    | 11    | 11   | 11
# doofus | dingus | bob | alice | p2    | p1    | darp | blarp
# 10100000 | 11111111
# A0 0F
n_variants = bim.shape[0]

genotypes = ['a0', 'ff'] # * n_variants # just repeat for second variant
dummy_genotypes = ['ff'] * 13 # remaining blocks
full_geno = (genotypes + dummy_genotypes) * n_variants
genobytes = bytes.fromhex(''.join(magic_numbers + full_geno))

with open('test.bed', 'w+b') as f:
    f.write(genobytes)

# score some stuff
# plink2 --bfile test --score test.scores no-mean-imputation cols=dosagesum,scoreavgs,denom,scoresums
