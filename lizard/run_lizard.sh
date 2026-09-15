#!/bin/bash
set -e

PROJECT_DIR="../ne-ljuti-se-covece"
RESULT_FILE="results/lizard.txt"

mkdir -p results

lizard \
  "$PROJECT_DIR/src/common" \
  "$PROJECT_DIR/src/server" \
  "$PROJECT_DIR/src/game" \
  > "$RESULT_FILE" || true

echo
echo "Lizard analysis completed."
echo

tail -n 20 "$RESULT_FILE"
