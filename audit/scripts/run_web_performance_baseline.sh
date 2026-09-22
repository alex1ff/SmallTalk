#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

BASELINE_PATH="${1:-audit/performance_baselines/web-profile-2026-09-07.json}"
OUTPUT_DIR="${2:-output/playwright}"
MANIFEST_PATH="$OUTPUT_DIR/web-build-manifest.json"
RAW_PATH="$OUTPUT_DIR/web-startup.json"
CANDIDATE_PATH="$OUTPUT_DIR/web-candidate.json"
SESSION="expatlio-perf-v1"
PORT="8765"
CLI_PACKAGE="@playwright/cli@0.1.19"
EXPECTED_CLI_VERSION="0.1.19"
SERVER_PID=""

cleanup() {
  npx --yes --package "$CLI_PACKAGE" playwright-cli --session "$SESSION" close \
    >/dev/null 2>&1 || true
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$OUTPUT_DIR"
ACTUAL_CLI_VERSION="$(npx --yes --package "$CLI_PACKAGE" playwright-cli --version)"
if [[ "$ACTUAL_CLI_VERSION" != "$EXPECTED_CLI_VERSION" ]]; then
  echo "Expected Playwright CLI $EXPECTED_CLI_VERSION, got $ACTUAL_CLI_VERSION" >&2
  exit 1
fi

node audit/scripts/prepare_web_performance_build.js "$MANIFEST_PATH"
MANIFEST_RUN_ID="$(node -e \
  'const fs=require("node:fs"); const value=JSON.parse(fs.readFileSync(process.argv[1], "utf8")).runId; if (!value) process.exit(1); process.stdout.write(value);' \
  "$MANIFEST_PATH")"

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory build/web \
  >"$OUTPUT_DIR/web-server.log" 2>&1 &
SERVER_PID="$!"
for _ in {1..50}; do
  if curl --fail --silent "http://127.0.0.1:$PORT/" >/dev/null; then break; fi
  sleep 0.1
done
if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
  echo "Performance server failed to start; see $OUTPUT_DIR/web-server.log" >&2
  exit 1
fi
curl --fail --silent "http://127.0.0.1:$PORT/" >/dev/null

LAUNCH_URL="http://127.0.0.1:$PORT/?manifestRunId=$MANIFEST_RUN_ID&playwrightCliVersion=$ACTUAL_CLI_VERSION"
npx --yes --package "$CLI_PACKAGE" playwright-cli --session "$SESSION" open "$LAUNCH_URL" \
  >/dev/null
npx --yes --package "$CLI_PACKAGE" playwright-cli --session "$SESSION" --json run-code \
  "$(cat audit/scripts/collect_web_startup.playwright.js)" >"$RAW_PATH"
node audit/scripts/record_web_performance_evidence.js "$MANIFEST_PATH" "$RAW_PATH"

node audit/scripts/create_web_performance_snapshot.js \
  "$BASELINE_PATH" "$MANIFEST_PATH" "$RAW_PATH" "$CANDIDATE_PATH"
node audit/scripts/validate_performance_budget.js "$BASELINE_PATH" "$CANDIDATE_PATH"

echo "Performance candidate: $CANDIDATE_PATH"
