#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIREBASE_BIN="${REPO_ROOT}/node_modules/.bin/firebase"
FUNCTIONS_NODE_MODULES="${REPO_ROOT}/firebase/custom_cloud_functions/node_modules"

if [[ ! -x "${FIREBASE_BIN}" ]]; then
  echo "Missing local firebase-tools." >&2
  echo "Run: npm ci --ignore-scripts" >&2
  exit 1
fi

if [[ ! -d "${FUNCTIONS_NODE_MODULES}/@firebase/rules-unit-testing" || \
      ! -d "${FUNCTIONS_NODE_MODULES}/firebase" ]]; then
  echo "Missing Firestore rules test dependencies." >&2
  echo "Run: npm ci --prefix firebase/custom_cloud_functions --ignore-scripts" >&2
  exit 1
fi

cd "${REPO_ROOT}"

"${FIREBASE_BIN}" emulators:exec \
  --project demo-smalltalk-rules-ci \
  --config firebase/firebase.json \
  --only firestore,storage \
  "node --test --test-concurrency=1 \
    firebase/custom_cloud_functions/user_document_rules.test.js \
    firebase/custom_cloud_functions/conversation_rules.test.js \
    firebase/custom_cloud_functions/call_integrations_rules.test.js \
    firebase/custom_cloud_functions/event_rules.test.js \
    firebase/custom_cloud_functions/teacher_verification_request_rules.test.js \
    firebase/custom_cloud_functions/search_request_rules.test.js \
    firebase/custom_cloud_functions/firestore_access_rules.test.js \
    firebase/custom_cloud_functions/storage_rules.test.js"
