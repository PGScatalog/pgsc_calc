import pathlib
import pytest
import glob
import os


@pytest.mark.workflow('test score correlation')
def test_correlation(workflow_dir):
    scores_dir = pathlib.Path(workflow_dir, "output/score/")
    df = pd.read_table("output/score/aggregated_scores.txt.gz")
    df = df.filter(['IID'] + list(df.filter(regex='SUM').columns))
    df.columns = df.columns.str.removesuffix('_hmPOS_GRCh37_SUM')

    baseline_scores = pd.read_table("tests/scores/1000G.sscore.gz", sep="\t")

    corr = baseline_scores.corrwith(calculated_scores)
    corr.to_csv("correlations.csv")
    for index, value in corr.items():
        assert value > 0.99, f'Score {index} fails correlation test with r {value}'
