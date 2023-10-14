@_default:
  just -l

# ALIASES

[private]
alias ds := docs-serve

[private]
alias ft := fix-and-test

[private]
alias ta := test-all

# Install the project dependencies
install:
  make dependencies

# Install the project dependencies, but quietly
# (to be used as a dependency for all other recipes)
_deps:
  @make -s dependencies

# Install the pre-commit hooks
install-hooks: _deps
  poetry run pre-commit install

# Run checks (hooks & type-checker)
check: _deps && typecheck
  poetry run pre-commit run --all-files

# Run checks (twice in case of failure) and all tests
fix-and-test: _deps && test-all
  @poetry run pre-commit run -a || poetry run pre-commit run -a

# Run all tests
test-all: _deps
  poetry run pytest

# Run all tests and generate coverage report
test-with-coverage: _deps
  poetry run pytest --cov=acl_anthology --cov-report=xml

# Run only test functions containing TERM
test TERM: _deps
  poetry run pytest -v -k _{{TERM}}

# Run all tests on all supported Python versions
test-all-python-versions: _deps
  #!/usr/bin/env bash
  set -eux
  # Restore the currently active Poetry environment on exit
  trap "poetry env use $(poetry env info -e)" EXIT
  # Loop over all supported Python versions
  for py in 3.10 3.11 3.12; do
    poetry env use $py
    poetry install --with dev --quiet
    poetry run pytest
  done

# Run type-checker only
typecheck: _deps
  poetry run mypy acl_anthology

# Build the documentation
docs: _deps
  poetry run mkdocs build

# Build and serve the documentation locally
docs-serve: _deps
  poetry run mkdocs serve

# Check that there are no uncommited changes
_no_uncommitted_changes:
  git update-index --refresh
  git diff-index --quiet HEAD --

# Bump version, update changelog, build new package, create a tag
prepare-new-release VERSION: _no_uncommitted_changes check test-all docs
  #!/usr/bin/env bash
  set -eux
  # Set trap to revert on error
  trap 'git checkout -- CHANGELOG.md pyproject.toml' ERR
  # Bump version
  poetry version {{VERSION}}
  # Update changelog
  VERSION=$(poetry version --short)
  DATE=$(date -u +%Y-%m-%d)
  sed -i "s/^## \[Unreleased\].*\$/## [Unreleased]\n\n## [$VERSION] — $DATE/" CHANGELOG.md
  # Build package
  poetry build
  # Create a tag
  git tag "v$VERSION"
  # Done!
  echo ""
  echo "### New release created: $VERSION"
  echo ""
  echo "Next steps:"
  echo "  1. git push --tags"
  echo "  2. poetry publish"
  echo "  3. Create a release on Github"
