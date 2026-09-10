#!/bin/bash

set -e

PROJECT_DIR="../ne-ljuti-se-covece"
BUILD_DIR="$PROJECT_DIR/build-fuzz"
RESULT_FILE="results/libfuzzer.txt"

rm -rf "$BUILD_DIR"

cmake -S "$PROJECT_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
  -DCMAKE_CXX_FLAGS="-fsanitize=fuzzer-no-link,address -fno-omit-frame-pointer" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address"

cmake --build "$BUILD_DIR" --target common -j

clang++ \
  -std=c++17 \
  -fsanitize=fuzzer,address \
  fuzz_messagefactory.cpp \
  -I"$PROJECT_DIR/src/common" \
  -L"$BUILD_DIR/src/common" \
  -lcommon \
  $(pkg-config --cflags --libs Qt6Core) \
  -Wl,-rpath,"$PWD/../ne-ljuti-se-covece/build-fuzz/src/common" \
  -o fuzz_messagefactory

mkdir -p corpus results

./fuzz_messagefactory \
  corpus \
  -max_total_time=30 \
  -print_final_stats=1 \
  > "$RESULT_FILE" 2>&1

echo
echo "libFuzzer analysis completed."
echo
tail -n 10 "$RESULT_FILE"
