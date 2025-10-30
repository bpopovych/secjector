SHELL := /bin/bash

.PHONY: help docs test test-integration lint

help:
	@echo "Targets:"
	@echo "  docs               - build MkDocs site"
	@echo "  test               - run lightweight checks"
	@echo "  test-integration   - run integration test against a RouterOS host (env required)"
	@echo "  lint               - markdown + yaml lint"

docs:
	@mkdocs build --strict

test:
	@bash -c 'grep -q "secrets.rsc" README.md && echo "README sanity: ok"'
	@bash -c 'test -f examples/secrets.yaml && echo "examples exist: ok"'
	@tests/unit/test_regressions.py

test-integration:
	@test -n "$$ROUTER_HOST" && test -n "$$ROUTER_USER" && test -n "$$ROUTER_IDENT" || \
	 (echo "Set ROUTER_HOST/ROUTER_USER/ROUTER_IDENT"; exit 0)
	tests/integration/test_apply.sh

lint:
	@command -v yamllint >/dev/null && yamllint -s . || echo "yamllint not installed - skip"
	@command -v markdownlint >/dev/null && markdownlint '**/*.md' || echo "mdl not installed - skip"
