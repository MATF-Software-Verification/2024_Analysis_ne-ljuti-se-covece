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

## Additional controlled experiments

The following experiments supplement the original analysis with isolated comparisons of test setup and object ownership. The saved logs refer to a temporary source copy and build under `/tmp/asan-controlled-sgfxeym0/`. Experimental changes are recorded in the linked patch files; this documentation update does not apply those patches to the project.

All controlled runs used Qt 6 with the following environment:

```bash
QT_QPA_PLATFORM=offscreen ASAN_OPTIONS=detect_leaks=1
```

These runs selected individual tests or sections and used the offscreen platform. Their leak totals should therefore not be directly compared with the earlier filtered suite using Qt/Wayland.

### Experiment 1: Explicit turn setup in ActivateMagicMessageHandlerTest

The isolated test was selected with `ActivateMagicMessageHandlerTest` as the Catch2 filter.

Before the experimental change, the valid-message section failed its empty-error-message assertion. The no-magic section then triggered `QList::at: "index out of range"` and `SIGABRT`. The log recorded 4 passed and 2 failed assertions, with `PROCESS_RETURN_CODE=-6`. Execution did not reach a final LeakSanitizer report.

The [test setup patch](results/controlled_magic_setup.patch) explicitly sets the current player color to `Color::Blue`, matching the participant, in each section. The wrong-turn section subsequently sets it to `Color::Red` to preserve that negative scenario. The patch also checks that the `dynamic_cast<ActivateMagicResponse*>` result is non-null before dereferencing it.

With this setup, all 16 assertions in the test passed and execution reached leak detection. LeakSanitizer then reported:

```text
SUMMARY: AddressSanitizer: 14332 byte(s) leaked in 205 allocation(s).
PROCESS_RETURN_CODE=1
```

This supports the conclusion that explicit turn setup resolves the observed assertion failure and abort in this isolated test. It does not resolve its memory leaks: passing Catch2 assertions and a clean sanitizer result are separate outcomes. The Qt assertion itself is not an ASan out-of-bounds diagnostic.

Saved outputs: [before the setup change](results/controlled_magic_before.txt) and [after the setup change](results/controlled_magic_after.txt).

### Experiment 2: Board lifetime and ownership of child objects

This experiment selected only the section that checks whether a pawn can leave its home:

```text
BoardTest -c "BoardTest: Validacija izlazenje  piuna iz kucice"
```

The same section was compared in three ownership configurations:

| Configuration | Catch2 result | LeakSanitizer result | Process return code |
| --- | --- | --- | --- |
| Original allocation with `new Board(4)` | 6 assertions passed | 23728 bytes in 353 allocations | 1 |
| Board managed by `std::unique_ptr` only | 6 assertions passed | 22902 bytes in 348 allocations | 1 |
| Board managed by `std::unique_ptr`, with child ownership added | 6 assertions passed | No leak report | 0 |

The [Board lifetime patch](results/controlled_board_root.patch) replaces the raw allocation in this section with `std::make_unique<Board>(4)`, ensuring that the Board is destroyed when the section exits. This reduced the reported leaks by 826 bytes and 5 allocations, but most leaks remained. Destroying the Board alone was therefore insufficient in this scenario.

The [child ownership patch](results/controlled_board_ownership.patch), used together with the Board lifetime change, establishes QObject parent relationships:

- `Board` becomes the parent of its `Player` objects and table `Square` objects.
- `Player` becomes the parent of its `Pawn` objects and start and finish `Square` objects.
- The `Pawn` constructor forwards its parent to the `QObject(parent)` base constructor.

With these relationships, destruction of the Board also destroys its owned descendants. The final isolated run passed all 6 assertions, produced no ASan/LeakSanitizer error report, and exited with code 0.

Saved outputs: [original ownership](results/controlled_board_before.txt), [Board lifetime change only](results/controlled_board_root_only.txt), and [Board lifetime plus child ownership](results/controlled_board_owned.txt).

### Interpretation and scope

The Board comparison provides additional evidence of incomplete object lifetime management in the selected project scenario: automatic destruction of the Board reduced the leaks, and adding ownership of its descendants removed the remaining reported leaks in that run. This is stronger evidence than the indirect allocation traces alone in the original analysis.

The results apply to the selected tests and experimental configurations. They do not establish that the complete suite or application is free of memory errors, nor do they account for every leak in the earlier Qt/Wayland run. The magic-handler experiment still reports leaks after its functional assertions pass.


## Additional analysis: standalone gameplay

The original server and game applications were run manually from the submodule, with one server and two clients, independently of Catch2. A separate Debug build in `ne-ljuti-se-covece/build-asan-game` used `-fsanitize=address -fno-omit-frame-pointer` and the executable linker flag `-fsanitize=address`. Only the `server` and `game` targets were requested. Each process was launched with `ASAN_OPTIONS=detect_leaks=1`; the client traces contain Qt 6 and Wayland frames. The earlier controlled patches were not applied for this scenario.

### Scenario and saved results

The logs show creation of a game for two human players with two bots, joining and starting the game, dice rolls, pawn movement and end-turn responses. They also contain requests for `double_dice`, `shield`, `plus_1` and `remote_dice`. Both clients eventually disconnected. This records a gameplay session; it does not establish that a game was completed to victory. Exact duration and exit statuses were not recorded.

| Process | LeakSanitizer result | Saved log |
| --- | --- | --- |
| Server | No final leak report | [game_server.txt](results/game_server.txt) |
| Client 1 | 6885 bytes in 74 allocations | [game_client.txt](results/game_client.txt) |
| Client 2 | 6964 bytes in 69 allocations | [game_client2.txt](results/game_client2.txt) |

Both clients reached a final LeakSanitizer summary. No use-after-free, buffer-overflow or double-free diagnostic appears in the three logs. The server records successful startup and both clients disconnecting, but its missing leak summary prevents a conclusion about server leaks. Stopping it with Ctrl+C, as in the manual procedure, does not establish normal cleanup; the log itself does not record the termination signal.

A separate [gameplay analysis report](results/gameplay_analysis.md) preserves the direct/indirect subtotals, allocation interpretation and limitations alongside the raw logs.

### Allocation findings

All direct leak records in the clients originate from `libwayland-client` allocations. This does not by itself prove that the platform is solely responsible: some paths include application GUI actions, and stronger attribution would require a minimal Qt control or backend comparison.

Client 2 also reports project-specific indirect allocations:

- In `JoinGameResponseHandler::handleResponse` (`src/game/client/handlers.cpp:69`), `QMessageBox::information(new QWidget(), ...)` creates a parent widget whose deletion is not arranged. The log includes its 40-byte allocation and related Qt allocations. This is the same source location identified in the standalone Valgrind analysis, although ASan classifies this allocation as indirect.
- In `MainWindow::on_joinButton_clicked` (`src/game/view/mainwindow.cpp:94`), the log includes the 24-byte allocation of `new DefaultResponseHandler`. The `ClientChainElement` constructor uses the next handler as its QObject parent; destroying the stack-allocated handler does not delete that parent. The allocation and related QObject traces identify another ownership issue to investigate.

These records are already included in the totals. Neither the Qt frames nor the indirect classification justify dismissing the project ownership issues. Differences from test or Valgrind byte totals must not be interpreted as a direct measurement of production leakage.

### Conclusion of the standalone experiment

The gameplay run detected leaks in both standalone clients, independently of test cleanup, and provided additional evidence of incomplete ownership in the join-game GUI and handler setup. No other ASan memory-access error was reported on the executed paths. The server cannot be classified as leak-free because it has no final LeakSanitizer report. These findings extend the earlier analysis without establishing that all application paths or shutdown behavior have been verified.


## Repeating the controlled ASan experiments

The saved temporary path above identifies the historical run; it is not needed to repeat it. The [controlled experiment runner](run_controlled_asan.sh) exports project commit `b50bedc6240d0f02dba7c2fed278bbcf3b80900d` from the local submodule into a new temporary directory. It does not modify the submodule working tree or depend on the old `/tmp/asan-controlled-sgfxeym0` directory.

Requirements are Bash, Git, tar, patch, CMake, GCC/G++ with ASan support and Qt 6 development packages. Initialize the project submodule first. From `address_sanitizer/`, run:

```bash
./run_controlled_asan.sh
```

The runner writes directly to the existing `results/` directory, replacing the five controlled measurement reports listed below. It does not create numbered repeat directories or change the patch files, original suite logs or gameplay logs. The documented totals describe the saved measurements; if a new run differs, review its logs and update the interpretation accordingly. `--jobs 4` controls build parallelism (4 is the default). The runner builds only the test target, uses `QT_QPA_PLATFORM=offscreen` and `ASAN_OPTIONS=detect_leaks=1`, and performs these steps in order:

1. Run the original isolated magic test and selected Board section.
2. Apply `controlled_magic_setup.patch`, rebuild, and rerun the magic test.
3. Apply `controlled_board_root.patch`, rebuild, and rerun the Board section.
4. Apply `controlled_board_ownership.patch` on top of the previous changes, rebuild, and rerun the same Board section.

The documentation refers to this single set of controlled measurement reports:

| Experiment | Result file |
| --- | --- |
| Original magic test | [controlled_magic_before.txt](results/controlled_magic_before.txt) |
| Magic test with explicit setup | [controlled_magic_after.txt](results/controlled_magic_after.txt) |
| Original Board section | [controlled_board_before.txt](results/controlled_board_before.txt) |
| Automatic Board destruction only | [controlled_board_root_only.txt](results/controlled_board_root_only.txt) |
| Automatic Board destruction and child ownership | [controlled_board_owned.txt](results/controlled_board_owned.txt) |

Each report includes its process return code. Auxiliary `setup.txt` and `build.txt` files remain in the temporary workspace printed by the script, alongside the source and build. Setup or build failures stop the script. Nonzero test/sanitizer statuses are recorded without stopping subsequent measurements, since failures and leaks are part of the comparison. Successful script completion is not a claim that every measurement passed: inspect the reports. The temporary workspace is retained for inspection.

Run without another game server or test process occupying localhost port 12345. The test executable instantiates the server even for the selected tests. ASan/LeakSanitizer must be permitted to execute normally; sandbox or tracing restrictions can prevent a valid leak check. Allocation totals and the uninitialized-state baseline behavior can vary with the environment, so compare diagnostics and ownership configurations rather than requiring identical byte counts.

The runner was validated with all five measurements. The Board reports reproduced 23728 bytes / 353 allocations, then 22902 bytes / 348 allocations, then no leak report with exit code 0. The patched magic test passed 16 assertions and reproduced 14332 bytes / 205 allocations. Both magic logs in this validation also reported `Server could not start!`, so that run did not verify successful server startup. The runner prints warnings for this condition and for a fatal LeakSanitizer initialization/check failure; inspect the corresponding logs before interpreting a repeat run.

The controlled runner uses Bash, consistently with the other analysis scripts. Signal termination is recorded using shell exit statuses (for example, SIGABRT is 134), whereas historical Python-generated reports used negative signal numbers (SIGABRT was -6). These represent the same signal, not different test outcomes.
