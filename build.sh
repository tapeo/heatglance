#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "--clean" ]; then
  rm -rf build
  shift
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is missing. Install it with: brew install xcodegen"
  exit 1
fi

CONFIGURATION="${1:-Debug}"
BUILD_DIR="${HEATGLANCE_BUILD_DIR:-build}"

xcodegen generate
xcodebuild \
  -project HeatGlance.xcodeproj \
  -scheme HeatGlance \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$BUILD_DIR" \
  build
