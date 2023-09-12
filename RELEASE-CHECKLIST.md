# Development

- [ ] Are there open jira tickets which should be included in the release?
- [ ] Are there open github issues which should be included in the release?
- [ ] Is everybody happy to release?

# Update dependencies 

- [ ] Check if plink2 or pgscatalog_utils have been updated since last pgsc_calc release
- [ ] Confirm dependencies work on docker, singularity, and conda
- [ ] Confirm dependencies working on amd64 and arm64
- [ ] Confirm versions are consistent across platforms
- [ ] Confirm the test suite correctly checking the version of tools
- [ ] Confirm modules point to the correct container image

## pgscatalog_utils

- [ ] Don't forget to bump version
- [ ] Is the test suite passing?
- [ ] Confirm no new features are needed
- [ ] Submit package to pypi
- [ ] Build docker and singularity images locally
- [ ] Push images to Gitlab repository
- [ ] Update the conda environment

# Documentation

- [ ] Check Github issues for documentation tags, review if new docs need to be written
- [ ] Make sure docs are building and published on readthedocs
- [ ] Has documentation been reviewed by somebody with fresh eyes?
- [ ] Has the changelog been updated?
- [ ] Update the nextflow schema

# Tests

- [ ] Make sure unit tests pass on singularity, docker, and conda (CI)
- [ ] Make sure score tests pass on singularity, docker, and conda (run locally) 

# Publish

- [ ] Tag new release with semver on dev branch (in `nextflow.config`)
- [ ] Submit PR
- [ ] Submit to FAIR workflow registry
- [ ] Announce!
