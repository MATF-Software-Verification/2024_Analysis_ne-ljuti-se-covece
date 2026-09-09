#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-asan"
RESULT_FILE="results/asan_without_activate_magic.txt"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
  -DCMAKE_CXX_FLAGS="-fsanitize=address -fno-omit-frame-pointer" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address"

cmake --build "$BUILD_DIR" -j

ASAN_OPTIONS=detect_leaks=1 \
"$BUILD_DIR/src/test/test" '~ActivateMagicMessageHandlerTest' \
> "$RESULT_FILE" 2>&1 || true

echo
echo "AddressSanitizer analysis completed."
echo
grep -E "ERROR: LeakSanitizer|SUMMARY: AddressSanitizer" "$RESULT_FILE" || true
