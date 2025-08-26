#!/usr/bin/env bash
set -euo pipefail
BUILD_DIR=${BUILD_DIR:-build}
TYPE=${BUILD_TYPE:-Release}
PREFIX=${INSTALL_PREFIX:-/usr/local}

mkdir -p "$(dirname "$0")/$BUILD_DIR"
cd "$(dirname "$0")/$BUILD_DIR"

cmake -DCMAKE_BUILD_TYPE="$TYPE" -DCMAKE_INSTALL_PREFIX="$PREFIX" ..
cmake --build . -j$(nproc || echo 4)

if [[ "${INSTALL:-false}" == "true" ]]; then
  cmake --install .
fi

echo "Built binary at $(pwd)/DicomViewer"