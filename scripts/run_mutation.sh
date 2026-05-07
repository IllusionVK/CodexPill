#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AGENT_NAME="${AGENT_NAME:-local}"
ARTIFACT_DIR="build/verification/mutation"
SUMMARY_PATH="$ARTIFACT_DIR/summary.md"
JSON_PATH="$ARTIFACT_DIR/muter-report.json"
PLAIN_PATH="$ARTIFACT_DIR/muter-report.txt"
MUTER_FILES=(
  "Sources/Core/Models/CodexRateLimits.swift"
  "Sources/Features/Accounts/Application/AccountActionFlow.swift"
  "Sources/Features/Accounts/Application/InactiveAccountAvailabilityRanking.swift"
  "Sources/Features/Hosts/Application/RemoteRateLimitResolution.swift"
)

write_summary_header() {
  mkdir -p "$ARTIFACT_DIR"
  {
    echo "# Mutation Testing Setup Report"
    echo
    echo "- Baseline test command: AGENT_NAME=$AGENT_NAME make test"
    echo "- Tool: Muter"
    echo "- Scope:"
    for source_file in "${MUTER_FILES[@]}"; do
      echo "  - $source_file"
    done
    echo "- Command: AGENT_NAME=$AGENT_NAME make mutation"
    echo "- Artifact directory: $ARTIFACT_DIR"
    echo "- Policy: report-only; no CI gate and no mutation score threshold"
  } > "$SUMMARY_PATH"
}

append_summary() {
  printf '%s\n' "$1" >> "$SUMMARY_PATH"
}

write_summary_header

if ! make test AGENT_NAME="$AGENT_NAME"; then
  append_summary "- Result: blocked before mutation"
  append_summary "- Blocker: baseline make test failed, so Muter was not run"
  echo "Baseline make test failed; mutation testing was not run. See $SUMMARY_PATH."
  exit 1
fi

if ! command -v muter >/dev/null 2>&1; then
  append_summary "- Result: blocked before mutation"
  append_summary "- Blocker: muter executable is not available on PATH"
  append_summary "- Recovery: install Muter, for example with Homebrew: brew install muter-mutation-testing/formulae/muter"
  echo "Muter is not available on PATH; mutation testing was not run. See $SUMMARY_PATH."
  exit 127
fi

TUIST_SKIP_UPDATE_CHECK=1 tuist generate --no-open

rm -f "$JSON_PATH" "$PLAIN_PATH"

if muter run \
  --skip-update-check \
  --configuration muter.conf.yml \
  --files-to-mutate "$(IFS=,; echo "${MUTER_FILES[*]}")" \
  --format json \
  --output "$JSON_PATH"; then
  append_summary "- JSON report: $JSON_PATH"
else
  append_summary "- Result: Muter JSON run failed"
  append_summary "- JSON report: $JSON_PATH, if Muter created a partial report"
  echo "Muter JSON run failed. See $SUMMARY_PATH."
  exit 1
fi

if muter run \
  --skip-update-check \
  --configuration muter.conf.yml \
  --files-to-mutate "$(IFS=,; echo "${MUTER_FILES[*]}")" \
  --format plain \
  --output "$PLAIN_PATH"; then
  append_summary "- Human-readable report: $PLAIN_PATH"
  append_summary "- Result: completed"
else
  append_summary "- Human-readable report: unavailable; plain report generation failed after JSON report"
  append_summary "- Result: completed with JSON report only"
fi

echo "Mutation report written to $ARTIFACT_DIR."
