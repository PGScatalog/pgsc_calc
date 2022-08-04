import pytest
import pathlib
import numpy as np
import pandas as pd
import glob
import os


@pytest.mark.workflow('test apply score subworkflow')
def test_aggregated_scores(workflow_dir):
    ''' Make sure aggregated scores are floats with no missing values '''

    score_dir = pathlib.Path(workflow_dir, "output/score/")
    agg_scores = glob.glob(os.path.join(score_dir, "*.txt.gz"))[0]

    df = pd.read_csv(agg_scores, sep = ' ')

    assert not df.isnull().any().any(), 'Missing values in aggregated scores'

    numeric_cols = df.select_dtypes(include = ['int64', 'float64'])
    weight_cols = df.drop(['dataset', 'IID'], axis = 1)
    assert weight_cols.equals(numeric_cols), "Weight columns aren't numeric"
