#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${REPO_ROOT}"

while IFS= read -r -d '' source_file; do
  node --check "${source_file}"
done < <(
  find firebase/functions firebase/custom_cloud_functions \
    -type f \
    -name '*.js' \
    -not -path '*/node_modules/*' \
    -print0
)

npm --prefix firebase/custom_cloud_functions run test:events
