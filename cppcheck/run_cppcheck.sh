#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
RESULT_FILE="results/cppcheck.txt"

cppcheck \
  --enable=warning,performance,portability \
  --inconclusive \
  --std=c++17 \
  --suppress=missingIncludeSystem \
  -Dslots= \
  "$PROJECT_DIR/src/common" \
  "$PROJECT_DIR/src/server" \
  "$PROJECT_DIR/src/game" \
  2> "$RESULT_FILE"

echo
echo "Cppcheck analysis completed."
echo
cat "$RESULT_FILE"
