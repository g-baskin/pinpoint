#!/bin/bash
# Runs the project's checks: build with warnings as errors, tests, shellcheck, and a swift-format report.
# Usage: scripts/check.sh
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== build (warnings are errors)"
swift build -Xswiftc -warnings-as-errors
echo "== tests"
swift test
echo "== shellcheck"
shellcheck scripts/*.sh
echo "== swift-format (report only until the codebase is reformatted)"
count="$(swift format lint --configuration .swift-format -r Sources Tests Package.swift 2>&1 | grep -c 'warning:' || true)"
echo "swift-format: $count style findings"
echo "All checks passed."
