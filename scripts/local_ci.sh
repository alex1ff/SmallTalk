#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

flutter pub get
flutter analyze
flutter test

npm ci --prefix firebase/functions
npm ci --prefix firebase/custom_cloud_functions
npm run backend:ci
