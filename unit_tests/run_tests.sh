#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-coverage"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
  -DCMAKE_CXX_FLAGS="--coverage"

cmake --build "$BUILD_DIR" -j

"$BUILD_DIR/src/test/test"

lcov --capture \
  --directory "$BUILD_DIR" \
  --output-file coverage.info

lcov --remove coverage.info \
  '/usr/*' \
  '*/src/test/*' \
  '*/build-coverage/*' \
  --output-file results/coverage_filtered.info

lcov --summary results/coverage_filtered.info \
  > results/coverage_summary.txt 2>&1

echo "Coverage analysis completed."
cat results/coverage_summary.txt
