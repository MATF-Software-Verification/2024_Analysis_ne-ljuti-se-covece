#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-clang-tidy"
RESULT_FILE="results/clang_tidy.txt"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

cmake --build "$BUILD_DIR" -j

find "$PROJECT_DIR/src/common" \
     "$PROJECT_DIR/src/server" \
     "$PROJECT_DIR/src/game" \
  -name "*.cpp" \
  -print0 | \
xargs -0 clang-tidy \
  -p "$BUILD_DIR" \
  > "$RESULT_FILE" 2>&1

echo
echo "clang-tidy analysis completed."
echo
grep -n -E "warning:|error:" "$RESULT_FILE" || true
