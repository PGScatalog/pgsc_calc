# pgsc_calc/Makefile
# Makefile to simplify installation and testing, try make help

install: ## Install and check dependencies
	@java --version
	@docker version
	curl -s https://get.nextflow.io | bash
	nextflow pull pgscatalog/pgsc_calc
	python3 -m pip install --user pytest-workflow pyliftover pandas requests

run: ## Run an example workflow
	nextflow run pgscatalog/pgsc_calc -profile test,docker

test: clean pytest ## Run pytest in a clean environment

pytest:
	PROFILE=docker pytest --kwdof --git-aware

clean: ## Clean temporary files
	rm -rf ./work ./results ./__pycache__ ./.nextflow.* ./.pytest_cache ./output

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: install run test clean pytest help
