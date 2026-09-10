#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-ubsan"
RESULT_FILE="results/ubsan.txt"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
  -DCMAKE_CXX_FLAGS="-fsanitize=undefined -fno-omit-frame-pointer" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=undefined"

cmake --build "$BUILD_DIR" -j

UBSAN_OPTIONS=print_stacktrace=1 \
"$BUILD_DIR/src/test/test" \
> "$RESULT_FILE" 2>&1 || true

echo
echo "UndefinedBehaviorSanitizer analysis completed."
echo
grep -n -E "runtime error:|SUMMARY: UndefinedBehaviorSanitizer" "$RESULT_FILE" || true
