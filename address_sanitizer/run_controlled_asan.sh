#!/usr/bin/env bash
# Repeat the five controlled ASan measurements without modifying the submodule.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REVISION=b50bedc6240d0f02dba7c2fed278bbcf3b80900d
OUTPUT="$SCRIPT_DIR/results"
JOBS=4
usage() {
    echo "Usage: $0 [--jobs N]"
}
while (($#)); do
    case "$1" in
        --jobs)
            if (($# < 2)); then usage >&2; exit 2; fi
            JOBS=$2
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done
if [[ ! "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
    usage >&2
    exit 2
fi
# Use the same result names referenced by the documentation.
mkdir -p -- "$OUTPUT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/asan-controlled-XXXXXXXX")"
SOURCE="$WORK/source"
BUILD="$WORK/build"
mkdir -- "$SOURCE"
printf 'Revision: %s\nWorkspace: %s\n' "$REVISION" "$WORK" > "$WORK/setup.txt"
printf 'Isolated workspace and build logs (retained): %s\n' "$WORK"
printf 'Measurements will replace the five controlled_*.txt reports in %s\n' "$OUTPUT"

checked() {
    printf '\nCommand: ' >> "$WORK/build.txt"
    printf '%q ' "$@" >> "$WORK/build.txt"
    printf '\n' >> "$WORK/build.txt"
    "$@" >> "$WORK/build.txt" 2>&1
}
rebuild() {
    checked cmake --build "$BUILD" --target test -j "$JOBS"
}
apply_patch() {
    checked patch --batch --fuzz=0 -d "$SOURCE" -p1 -i "$SCRIPT_DIR/results/$1"
}
measure() {
    local name=$1 status=0
    shift
    local report="$OUTPUT/controlled_${name}.txt"
    {
        printf 'QT_QPA_PLATFORM=offscreen ASAN_OPTIONS=detect_leaks=1\nCommand: '
        printf '%q ' "$BUILD/src/test/test" "$@"
        printf '\n'
    } > "$report"
    QT_QPA_PLATFORM=offscreen ASAN_OPTIONS=detect_leaks=1 \
        "$BUILD/src/test/test" "$@" >> "$report" 2>&1 || status=$?
    printf '\nPROCESS_RETURN_CODE=%s\n' "$status" >> "$report"
    printf '%s: process return code %s\n' "$name" "$status"
    if grep -q 'Server could not start!' "$report"; then
        echo "WARNING: $name: server could not listen; check port 12345."
    fi
    if grep -q 'LeakSanitizer has encountered a fatal error' "$report"; then
        echo "WARNING: $name: LeakSanitizer could not complete; final leak measurement is invalid."
    fi
}

checked git -C "$SCRIPT_DIR/../ne-ljuti-se-covece" archive \
    --format=tar "--output=$WORK/source.tar" "$REVISION"
checked tar -xf "$WORK/source.tar" -C "$SOURCE"
checked cmake -S "$SOURCE" -B "$BUILD" \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_PREFIX_PATH=/usr/lib/x86_64-linux-gnu/cmake/Qt6 \
    '-DCMAKE_CXX_FLAGS=-fsanitize=address -fno-omit-frame-pointer' \
    -DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address

BOARD_SECTION='BoardTest: Validacija izlazenje  piuna iz kucice'
rebuild
measure magic_before ActivateMagicMessageHandlerTest
measure board_before BoardTest -c "$BOARD_SECTION"
apply_patch controlled_magic_setup.patch
rebuild
measure magic_after ActivateMagicMessageHandlerTest
apply_patch controlled_board_root.patch
rebuild
measure board_root_only BoardTest -c "$BOARD_SECTION"
apply_patch controlled_board_ownership.patch
rebuild
measure board_owned BoardTest -c "$BOARD_SECTION"
printf 'Finished; inspect all five reports in %s. Nonzero measurement statuses are recorded.\n' "$OUTPUT"
