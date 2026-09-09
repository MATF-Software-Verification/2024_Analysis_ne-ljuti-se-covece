# AddressSanitizer Analysis

## Description

AddressSanitizer (ASan) was used to perform dynamic memory analysis of the C++ project.

The project was compiled with:

```text
-fsanitize=address
-fno-omit-frame-pointer
```

Leak detection was enabled using:

```text
ASAN_OPTIONS=detect_leaks=1
```

The goal of this analysis was to detect memory errors such as invalid memory access, use-after-free, buffer overflows and memory leaks.

## Requirements

The following tools are required:

- CMake
- GCC/G++
- Qt 6
- AddressSanitizer support in GCC

No separate AddressSanitizer package is required because ASan support is included in GCC.

## Running the analysis

From the `address_sanitizer` directory run:

```bash
./run_asan.sh
```

The script:

1. Removes the previous ASan build directory.
2. Configures the project in Debug mode.
3. Enables AddressSanitizer instrumentation.
4. Builds the project.
5. Runs the Catch2 test suite with leak detection enabled.
6. Excludes `ActivateMagicMessageHandlerTest` from the leak analysis because the complete suite aborts before finishing due to an existing `QList::at` assertion failure.
7. Stores the full output in:

```text
results/asan_without_activate_magic.txt
```

## Full test suite behavior

When the complete test suite was executed under ASan, execution aborted during `ActivateMagicMessageHandlerTest`.

The output contained:

```text
ASSERT failure in QList::at: "index out of range"
```

followed by:

```text
SIGABRT - Abort (abnormal termination) signal
```

This prevented the complete suite from reaching the final LeakSanitizer phase.

Because of that, the final leak analysis was performed with:

```text
~ActivateMagicMessageHandlerTest
```

as a Catch2 test filter.

## LeakSanitizer results

The filtered run completed far enough for LeakSanitizer to report:

```text
ERROR: LeakSanitizer: detected memory leaks
SUMMARY: AddressSanitizer: 198924 byte(s) leaked in 2953 allocation(s).
```

## Direct leaks

The inspected direct leak traces were located in external Qt/Wayland libraries such as:

```text
libwayland-client
Qt6WaylandClient
Qt6Gui
Qt6Widgets
```

Therefore, those direct leaks were not attributed directly to the analyzed project.

## Indirect leaks involving project code

Some indirect leak traces passed through project code, including:

```text
Square::Square(QString, QObject*)       src/server/square.cpp:4
Board::initializeTable()                src/server/board.cpp:243
Board::Board(int, QObject*)             src/server/board.cpp:5
```

This means project objects are present in the retained allocation graph.

However, because these are indirect leaks, they are not treated as proof that `Square` or `Board` are the root cause of the leak. Additional ownership and lifetime analysis would be required to determine the exact source.

## Screenshots

The screenshots are stored in:

```text
pictures/
```

Recommended structure:

```text
address_sanitizer/
├── README.md
├── run_asan.sh
├── results/
│   └── asan_without_activate_magic.txt
└── pictures/
    ├── run_asan.png
    ├── leak_summary.png
    └── indirect_project_trace.png
```

## Conclusion

AddressSanitizer and LeakSanitizer detected memory leaks during execution of the test suite.

The reported summary was:

```text
198924 byte(s) leaked in 2953 allocation(s)
```

The direct leak traces that were inspected belonged to Qt/Wayland infrastructure and were therefore not attributed directly to the analyzed project.

Indirect leak traces did pass through `Square` and `Board` project code, but this alone is not sufficient to identify those classes as the root cause.

The complete test suite also aborted in `ActivateMagicMessageHandlerTest` due to an out-of-range `QList::at` assertion, which is consistent with the previously observed unstable state around player indexing.
