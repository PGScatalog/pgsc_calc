import pytest
import pathlib
import pandas as pd
import glob
import os
import itertools
import gzip
import re


@pytest.mark.workflow("test apply score subworkflow")
def test_aggregated_scores(workflow_dir):
    """Make sure aggregated scores are floats with no missing values"""

    score_dir = pathlib.Path(workflow_dir, "output/score/")
    agg_scores = glob.glob(os.path.join(score_dir, "*.txt.gz"))[0]

    df = pd.read_csv(agg_scores, sep="\t")

    assert not df.isnull().any().any(), "Missing values in aggregated scores"

    cols = ["sampleset", "FID", "IID", "PGS", "SUM", "DENOM", "AVG"]
    assert cols == list(df.columns), "Missing columns"
    assert (
        len(
            set(df.select_dtypes(include=["int64", "float64"]).columns).difference(
                set(
                    [
                        "SUM",
                        "AVG",
                        "DENOM",
                    ]
                )
            )
        )
        == 0
    )


@pytest.mark.workflow("test apply score subworkflow")
def test_processed_variants(workflow_dir):
    """Make sure n_lines in scorefile == --score XXX variants processed in log"""
    # find directories with scoring file variants in them
    scoring_variants = [
        pathlib.Path(x)
        for x in glob.glob("work/**/**/*.sscore.vars", root_dir=workflow_dir)
    ]
    not_symlinks = [not x.is_symlink() for x in scoring_variants]
    real_files: list[pathlib.Path] = [
        i for (i, v) in zip(scoring_variants, not_symlinks) if v
    ]
    work_dirs: list[pathlib.Path] = [x.parents[0] for x in real_files]

    for work_dir in work_dirs:
        plink_log_path = glob.glob("*.log", root_dir=workflow_dir / work_dir)[0]

        with open(workflow_dir / work_dir / plink_log_path) as f:
            log: list[str] = f.read().split("\n")

        # grab line from log: '--score: n variants processed.'
        processed_line: list[str] = list(
            itertools.compress(log, ["variants processed." in x for x in log])
        )[0]
        processed_variants: int = int(re.findall(r"\d+", processed_line)[0])

        scorefile_path = glob.glob("*.scorefile.gz", root_dir=workflow_dir / work_dir)[
            0
        ]
        with gzip.open(workflow_dir / work_dir / scorefile_path) as f:
            num_scorefile_lines = sum(1 for _ in f)

        # (-1 for header line)
        assert (
            num_scorefile_lines - 1 == processed_variants
        ), "plink log variants processed doesn't match scorefile n variants"
