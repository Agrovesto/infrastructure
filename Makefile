SHELL := /bin/bash
ROOTS := bootstrap/dev bootstrap/prod environments/dev environments/prod
PYTHON ?= python3

.PHONY: fmt fmt-check init validate test unit checkov scan check
fmt:
	terraform fmt -recursive
fmt-check:
	terraform fmt -recursive -check -diff
init:
	@set -e; for root in $(ROOTS); do terraform -chdir=$$root init -backend=false -lockfile=readonly; done
validate:
	@set -e; for root in $(ROOTS); do terraform -chdir=$$root validate -no-color; done
test:
	@set -e; for root in $(ROOTS); do terraform -chdir=$$root test -no-color; done
unit:
	$(PYTHON) -m coverage run -m unittest discover -s tests -v
	$(PYTHON) -m coverage report
	$(PYTHON) -m coverage xml
	find scripts -name '*.sh' -print0 | xargs -0 shellcheck
checkov:
	scripts/ci/checkov-checks.sh
scan:
	trivy fs --config trivy.yaml --scanners vuln,secret,misconfig .
check: fmt-check init validate test unit checkov scan
