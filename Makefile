.PHONY: lint format format-write push

# Run buf lint + format check (same as CI). Run this before every push.
lint:
	buf lint
	buf format --diff --exit-code

# Auto-fix formatting in place.
format:
	buf format --write

# Lint, format, and push to trigger BSR publish.
push: lint
	git add -A
	@echo "Linting passed. Run 'git commit' and 'git push' to publish to BSR."
