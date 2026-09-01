#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter pub get
flutter analyze
flutter test

npm ci --ignore-scripts
npm ci --prefix firebase/custom_cloud_functions --audit=false
npm audit --prefix firebase/custom_cloud_functions --omit=dev --audit-level=high
npm run backend:ci
npm run firestore:rules:test
npm --prefix firebase/custom_cloud_functions run test:legacy-fallback-manifest
npm --prefix firebase/custom_cloud_functions run test:performance-budget
npm --prefix firebase/custom_cloud_functions run test:critical-flow-matrix
