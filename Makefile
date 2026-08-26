.PHONY: lint lint-proto lint-openapi format format-write push

REDOCLY_VERSION := 1.34.1

# Run every contract check CI runs. Run this before every push.
lint: lint-proto lint-openapi

lint-proto:
	buf lint
	buf format --diff --exit-code

# The OpenAPI contract for the cacheable REST endpoints — see openapi/README.md.
lint-openapi:
	npx --yes @redocly/cli@$(REDOCLY_VERSION) lint

# Auto-fix proto formatting in place.
format:
	buf format --write

# Lint, format, and push to trigger BSR publish.
push: lint
	git add -A
	@echo "Linting passed. Run 'git commit' and 'git push' to publish to BSR."
