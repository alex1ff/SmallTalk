#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
FIREBASE_BIN="${FIREBASE_BIN:-${REPO_ROOT}/node_modules/.bin/firebase}"
FIREBASE_PROJECT="${FIREBASE_PROJECT:-smalltalk-2109b}"
MAX_ATTEMPTS=3
RETRY_SLEEP_SECONDS="${INVENTORY_RETRY_SLEEP_SECONDS:-1}"
INVENTORY_FILE="$(mktemp)"
trap 'rm -f "${INVENTORY_FILE}"' EXIT

if [[ ! -x "${FIREBASE_BIN}" ]]; then
  echo "Missing pinned firebase-tools. Run 'npm ci' in ${REPO_ROOT}." >&2
  exit 1
fi

for attempt in $(seq 1 "${MAX_ATTEMPTS}"); do
  if "${FIREBASE_BIN}" functions:list \
      --project "${FIREBASE_PROJECT}" \
      --config "${REPO_ROOT}/firebase/firebase.json" \
      --json >"${INVENTORY_FILE}" &&
    node "${SCRIPT_DIR}/validate_backend_source.js" \
      --production-json \
      "$@" <"${INVENTORY_FILE}"; then
    exit 0
  fi

  if [[ "${attempt}" -lt "${MAX_ATTEMPTS}" ]]; then
    echo "Backend inventory attempt ${attempt} failed; retrying." >&2
    sleep "$((attempt * RETRY_SLEEP_SECONDS))"
  fi
done

echo "Backend inventory failed after ${MAX_ATTEMPTS} attempts." >&2
exit 1
