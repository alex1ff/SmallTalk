#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIREBASE_BIN="${REPO_ROOT}/node_modules/.bin/firebase"

FIREBASE_PROJECT="${FIREBASE_PROJECT:-demo-smalltalk}"
FIREBASE_CONFIG_PATH="${FIREBASE_CONFIG_PATH:-firebase/firebase.json}"

cd "${REPO_ROOT}"

if [[ ! -x "${FIREBASE_BIN}" ]]; then
  echo "Missing local firebase-tools. Run 'npm install' in ${REPO_ROOT}." >&2
  exit 1
fi

"${FIREBASE_BIN}" emulators:exec \
  --project "${FIREBASE_PROJECT}" \
  --config "${FIREBASE_CONFIG_PATH}" \
  --only firestore,storage,functions \
  "node audit/scripts/backend_checks_runner.js"
