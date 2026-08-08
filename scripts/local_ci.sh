#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter pub get
flutter analyze
flutter test

npm ci --prefix firebase/functions --audit=false
npm ci --prefix firebase/custom_cloud_functions --audit=false
npm audit --prefix firebase/functions --omit=dev --audit-level=high
npm audit --prefix firebase/custom_cloud_functions --omit=dev --audit-level=high
npm run backend:ci
