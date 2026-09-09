#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-valgrind"
RESULT_FILE="results/memcheck.txt"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6

cmake --build "$BUILD_DIR" -j

valgrind \
  --tool=memcheck \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes \
  --log-file="$RESULT_FILE" \
  "$BUILD_DIR/src/test/test"

echo
echo "Valgrind Memcheck completed."
echo
tail -n 20 "$RESULT_FILE"
