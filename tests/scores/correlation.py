import pathlib
import pytest
import glob
import os


@pytest.mark.workflow('test score correlation')
def test_correlation(workflow_dir):
    scores_dir = pathlib.Path(workflow_dir, "output/score/")
    calculated_scores = read_calculated_scores(scores_dir)
    baseline_scores = read_baseline()
    corr = baseline_scores.corrwith(calculated_scores)
    for index, value in corr.items():
        assert value > 0.99, f'Score {index} fails correlation test with r {value}'


def read_calculated_scores(workflow_dir):
    # scores have datetime in their name
    scores = glob.glob(os.path.join(workflow_dir, "*.txt.gz"))[0]
    df = pd.read_table(scores, sep = " ")
    score_cols = (df.filter(regex='_SUM$')
                  .drop(['NAMED_ALLELE_DOSAGE_SUM', 'DENOM_SUM'], axis = 1))
    score_df = pd.concat([df[['IID']], score_cols], axis = 1)
    score_df.columns = score_df.columns.str.rstrip('_SUM')
    return score_df


def read_baseline(workflow_dir):
    path = pathlib.Path(workflow_dir, "tests/scores/1000G.sscore.gz")
    return pd.read_table(path, sep = "\t")  # why tabs?!
