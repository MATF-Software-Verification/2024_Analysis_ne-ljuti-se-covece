#!/bin/bash

set -e

# Keep the original test analysis as the default. Application modes do not run tests.
MODE="${1:-tests}"
case "$MODE" in
  tests|build|server|client|client2) ;;
  *) echo "Usage: ./run_valgrind.sh [tests|build|server|client|client2]" >&2; exit 2 ;;
esac

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-valgrind"
RESULT_FILE="results/memcheck.txt"

mkdir -p results

if [ "$MODE" = tests ] || [ "$MODE" = build ]; then
  # Build before launching the server/clients; do not rebuild a running binary.
  if [ "$MODE" = tests ]; then
    rm -rf "$BUILD_DIR"
  fi

  cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6

  if [ "$MODE" = build ]; then
    cmake --build "$BUILD_DIR" --target server game -j2
    echo "Server and client built. No tests were executed."
    exit 0
  fi
  cmake --build "$BUILD_DIR" -j
fi

if [ "$MODE" != tests ]; then
  case "$MODE" in
    server) EXECUTABLE="$BUILD_DIR/src/server/server" ;;
    client|client2) EXECUTABLE="$BUILD_DIR/src/game/game" ;;
  esac
  if [ ! -x "$EXECUTABLE" ]; then
    echo "Run ./run_valgrind.sh build first." >&2
    exit 2
  fi

  RESULT_FILE="results/memcheck_${MODE}.txt"
  APPLICATION_FILE="results/${MODE}_output.txt"
  STATUS_FILE="results/${MODE}_exit_code.txt"
  # Preserve previous application measurements until deliberately archived/removed.
  for file in "$RESULT_FILE" "$APPLICATION_FILE" "$STATUS_FILE"; do
    if [ -e "$file" ]; then
      echo "Existing result: $file. Archive it before repeating this scenario." >&2
      exit 2
    fi
  done

  # Ctrl+C reaches the foreground process group. Save its status afterwards;
  # this does not implement graceful application shutdown.
  trap ':' INT
  status=0
  echo "Running $MODE; application output: $APPLICATION_FILE"
  valgrind \
    --tool=memcheck \
    --leak-check=full \
    --show-leak-kinds=all \
    --track-origins=yes \
    --num-callers=30 \
    --error-exitcode=97 \
    --errors-for-leak-kinds=definite,possible \
    --log-file="$RESULT_FILE" \
    "$EXECUTABLE" > "$APPLICATION_FILE" 2>&1 || status=$?
  printf '%s\n' "$status" > "$STATUS_FILE"
  echo "Process status: $status (97 = Memcheck errors); report: $RESULT_FILE"
  if [ -f "$RESULT_FILE" ]; then tail -n 20 "$RESULT_FILE"; fi
  exit "$status"
fi

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
