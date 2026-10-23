#!/usr/bin/env sh
# Lint one Dockerfile (default: ./Dockerfile) with Hadolint running in Docker.
# Usage: ./scripts/lint.sh [path/to/Dockerfile]
FILE="${1:-Dockerfile}"
echo "==> hadolint $FILE"
docker run --rm -i \
  -v "$(pwd)/.hadolint.yaml:/.config/hadolint.yaml:ro" \
  hadolint/hadolint:v2.12.0 < "$FILE" \
  && echo "    (no issues found)"
