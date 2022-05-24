import pytest
import pathlib
import numpy as np
import pandas as pd

@pytest.mark.workflow('test apply score subworkflow')
def test_aggregated_scores(workflow_dir):
    ''' Make sure aggregated scores are floats with no missing values '''

    agg_scores = pathlib.Path(workflow_dir, "output/score/aggregated_scores.txt")
    df = pd.read_csv(agg_scores, sep = ' ')

    assert not df.isnull().any().any(), 'Missing values in aggregated scores'

    numeric_cols = df.select_dtypes(include = ['int64', 'float64'])
    weight_cols = df.drop(['dataset', 'IID'], axis = 1)
    assert weight_cols.equals(numeric_cols), "Weight columns aren't numeric"
