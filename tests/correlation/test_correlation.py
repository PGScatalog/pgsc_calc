import pathlib
import pytest
import pandas as pd 


@pytest.mark.workflow('test score correlation')
def test_correlation(workflow_dir: pathlib.Path):
    """ This test compares calculated polygenic scores (SUM) for PGS000018, PGS000027, PGS000039, PGS000137, PGS000727, PGS000728, and PGS000729 to two reference scores:

    1) Scores calculated with pgsc_calc v2.0.0-alpha.5 
    2) An independent R script which the workflow was based on developed by Scott Ritchie (see credits in README)

    If the scores don't correlate well, fail loudly.
    """
    calculated_score_path = workflow_dir / "output" / "test" / "score" / "aggregated_scores.txt.gz"
    ref_score_path = workflow_dir / "tests" / "correlation" / "PGS_SUM.txt.gz"
    pgsc_score_path = workflow_dir / "tests" / "correlation" / "PGS_SUM_alpha5.txt.gz"

    columns = ["PGS", "IID", "SUM"]
    calculated_df = pd.read_csv(calculated_score_path, sep="\t")[columns].rename(columns={"SUM": "CALC_SUM"})
    ref_df = pd.read_csv(ref_score_path, sep="\t")[columns].rename(columns={"SUM": "REF_INDEPENDENT_SUM"})
    pgsc_df = pd.read_csv(pgsc_score_path, sep="\t")[columns].rename(columns={"SUM": "REF_CALC_SUM"})
    ref_scores = pd.merge(ref_df, pgsc_df, on=["PGS", "IID"], how="left")
    
    merged_scores = pd.merge(ref_scores, calculated_df, on=["PGS", "IID"], how="left")
    merged_scores.to_csv(workflow_dir / "output" / "correlations.csv")
    
    for index, row in merged_scores[["CALC_SUM", "REF_INDEPENDENT_SUM", "REF_CALC_SUM"]].corr().iterrows():
        assert all(row > 0.999), f"Bad correlation for {index}"