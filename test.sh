#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

swift test --package-path Packages/HeatGlanceKit

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  echo "skipped: xcodegen is missing"
fi
