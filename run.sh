#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh "${1:-Debug}"

pkill -x HeatGlance >/dev/null 2>&1 || true
open build/Build/Products/Debug/HeatGlance.app
