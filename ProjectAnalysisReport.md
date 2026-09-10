# Project Analysis Report

## Existing tests and code coverage

### Tool/technique

The analyzed project contains an existing Catch2 test suite. The existing tests were executed and code coverage was measured using LCOV.

This section is used as supporting analysis and baseline information. LCOV is not counted as a separate verification technique.

### Procedure

The project was configured and built in Debug mode with GCC coverage instrumentation enabled using the `--coverage` compiler flag.

After the build completed, the existing Catch2 test executable was run. LCOV was then used to collect coverage data. System headers, generated build files and test source files were excluded from the final coverage report.

The analysis can be reproduced using:

```bash
cd unit_tests
./run_tests.sh
```

### Running the analysis

![Running the test and coverage script](unit_tests/pictures/run_tests.png)

### Test results

All existing tests passed successfully:

- 15 test cases
- 303 assertions
- 0 failed tests

![All tests passed](unit_tests/pictures/tests_passed.png)

### Code coverage results

- Line coverage: 73.2% (868/1185)
- Function coverage: 80.6% (179/222)
- Branch coverage: not collected

![LCOV coverage summary](unit_tests/pictures/coverage_summary.png)

### Conclusion

The existing test suite provides good function coverage and moderate line coverage. Approximately 27% of the source lines are not executed by the current test suite.

---

## Valgrind Memcheck

### Tool

Valgrind Memcheck was used to detect memory-related problems such as use of uninitialized values, invalid memory access and memory leaks.

The analysis can be reproduced using:

```bash
cd valgrind
./run_valgrind.sh
```

### Running the analysis

![Running Valgrind Memcheck](valgrind/pictures/run_valgrind.png)

### Test behavior under Memcheck

Under normal execution, all 15 test cases and all 303 assertions passed.

Under Valgrind Memcheck:

- 15 test cases
- 14 passed
- 1 failed
- 303 assertions
- 301 passed
- 2 failed

The failing assertions were in `ActivateMagicMessageHandlerTest`.

![Failing test under Valgrind](valgrind/pictures/failed_test.png)

### Project-specific finding

Valgrind reported that conditional control flow depends on an uninitialized value in:

```text
ActivateMagicMessageHandler::handleMessage() - handlers.cpp:273
```

The same value was later used through:

```text
GameManager::isMagicAvailable() - managers.cpp:70
Board::getPlayer() - board.cpp:207
```

`TurnContext::reset()` initializes several state fields, but does not initialize:

```cpp
currentPlayerColor
```

The value is later returned by `getCurrentPlayerColor()` and is ultimately used in player indexing.

![Uninitialized value reported by Memcheck](valgrind/pictures/uninitialized_value.png)

### Other Valgrind findings

Valgrind also reported invalid reads and memory leaks in Qt/Wayland/GTK-related code. These were not attributed directly to the analyzed project because their stack traces were located in external libraries.

### Memcheck summary

![Valgrind Memcheck summary](valgrind/pictures/memcheck_summary.png)

### Conclusion

Valgrind Memcheck detected a project-specific use of an uninitialized value. The field `TurnContext::currentPlayerColor` is not initialized before being used by game logic.

---

## Clang-Tidy

### Tool

Clang-Tidy was used for static analysis of the C++ source code in:

```text
src/common
src/server
src/game
```

The analysis can be reproduced using:

```bash
cd clang_tidy
./run_clang_tidy.sh
```

### Running the analysis

![Running Clang-Tidy](clang_tidy/pictures/run_clang_tidy.png)

### Null pointer warning

The most important finding was reported in:

```text
src/game/client/handlers.cpp:50
```

Clang-Tidy reported:

```text
Called C++ object pointer is null
[clang-analyzer-core.CallAndMessage]
```

The warning refers to:

```cpp
response->prepareMessage()
```

The analyzer determined that the execution path can reach this expression while `response` is null.

![Null pointer warning](clang_tidy/pictures/null_pointer_warning.png)

### Potential memory leaks

Clang-Tidy also reported three potential memory leaks:

```text
handlers.cpp:76
handlers.cpp:103
handlers.cpp:130
```

The warnings are related to dynamically allocated `QWidget` objects passed to `QMessageBox` calls.

![Potential memory leak warnings](clang_tidy/pictures/memory_leaks.png)

### Conclusion

Clang-Tidy found four project-specific warnings. The strongest finding is a possible null pointer dereference in `src/game/client/handlers.cpp`.

---

## Cppcheck

### Tool

Cppcheck was used for static analysis with focus on warnings, portability and performance issues.

The analysis was run over:

```text
src/common
src/server
src/game
```

The analysis can be reproduced using:

```bash
cd cppcheck
./run_cppcheck.sh
```

### Running the analysis

![Running Cppcheck](cppcheck/pictures/run_cppcheck.png)

### Uninitialized members

Cppcheck reported multiple uninitialized member variables, including:

```text
CreateGameResponse::color
Response::broadcast
ActivateMagicResponse::remainingMagicNumber
ActivateMagicResponse::newDiceNumber
BaseParticipant::gameManager
BaseParticipant::color
ServerThreadParticipant::socket
Client::color
```

![Uninitialized members reported by Cppcheck](cppcheck/pictures/uninitialized_members.png)

### TurnContext::currentPlayerColor

Cppcheck also reported:

```text
src/common/turncontext.cpp:3:14:
warning: Member variable 'TurnContext::currentPlayerColor'
is not initialized in the constructor. [uninitMemberVar]
```

![TurnContext warning](cppcheck/pictures/turncontext_warning.png)

This finding is particularly important because Valgrind Memcheck independently reported runtime use of an uninitialized value originating from the same `TurnContext` object.

### Conclusion

Cppcheck detected several project-specific cases of uninitialized member variables.

The strongest finding is `TurnContext::currentPlayerColor`, because it confirms the same defect already observed with Valgrind Memcheck.

---

## AddressSanitizer

### Tool

AddressSanitizer was used for dynamic memory analysis.

The project was compiled with:

```text
-fsanitize=address
-fno-omit-frame-pointer
```

Leak detection was enabled using:

```text
ASAN_OPTIONS=detect_leaks=1
```

The analysis can be reproduced using:

```bash
cd address_sanitizer
./run_asan.sh
```

### Running the analysis

![Running AddressSanitizer](address_sanitizer/pictures/run_asan.png)

### Full test suite behavior

The complete test suite did not finish under ASan.

Execution aborted in `ActivateMagicMessageHandlerTest` after Qt reported:

```text
ASSERT failure in QList::at: "index out of range"
```

The test process then terminated with `SIGABRT`.

Because the process aborted before the final leak report, the leak analysis was repeated while excluding `ActivateMagicMessageHandlerTest` using the Catch2 filter:

```text
~ActivateMagicMessageHandlerTest
```

### LeakSanitizer summary

The filtered run produced:

```text
ERROR: LeakSanitizer: detected memory leaks
SUMMARY: AddressSanitizer: 198924 byte(s) leaked in 2953 allocation(s).
```

![LeakSanitizer summary](address_sanitizer/pictures/leak_summary.png)

### Direct leak interpretation

The inspected direct leak traces were located in external Qt/Wayland components such as `libwayland-client`, `Qt6WaylandClient`, `Qt6Gui` and `Qt6Widgets`.

These direct leaks were therefore not attributed directly to the analyzed project.

### Indirect leak traces through project code

Some indirect leak traces passed through:

```text
Square::Square(QString, QObject*)       src/server/square.cpp:4
Board::initializeTable()                src/server/board.cpp:243
Board::Board(int, QObject*)             src/server/board.cpp:5
```

![Indirect leak trace through project code](address_sanitizer/pictures/indirect_project_trace.png)

These traces show that project objects are part of the retained allocation graph. However, because the findings are indirect leaks, they do not by themselves prove that `Square` or `Board` are the root cause.

### Conclusion

AddressSanitizer and LeakSanitizer reported `198924 byte(s) leaked in 2953 allocation(s)`.

The direct leak traces that were inspected belonged to Qt/Wayland infrastructure and were not attributed directly to the project. Indirect leak traces did pass through `Square` and `Board`, but additional ownership and lifetime analysis would be required to identify the exact root cause.

---

## libFuzzer

### Tool

LLVM libFuzzer was used to fuzz the message parsing logic implemented by:

```cpp
MessageFactory::createMessage(QByteArray)
```

The purpose was to generate and mutate a large number of inputs and test whether malformed or unexpected data could cause a crash or sanitizer-detected memory error.

The analysis can be reproduced using:

```bash
cd libfuzzer
./run_libfuzzer.sh
```

### Fuzz target

The fuzz target is stored in:

```text
libfuzzer/fuzz_messagefactory.cpp
```

For every generated byte buffer, it converts the input into a `QByteArray`, calls `MessageFactory::createMessage()`, deletes a successfully created message and catches the expected `std::runtime_error` for invalid or unknown message types.

Invalid message types are expected during fuzzing and therefore are not treated as failures.

### Instrumentation

The `common` library was built with:

```text
-fsanitize=fuzzer-no-link,address
-fno-omit-frame-pointer
```

The final fuzz executable was linked using:

```text
-fsanitize=fuzzer,address
```

This enabled libFuzzer coverage instrumentation and AddressSanitizer checks.

### Running libFuzzer

![Running libFuzzer](libfuzzer/pictures/run_libfuzzer.png)

The initial corpus contained a valid-looking JSON message and an invalid text input.

During fuzzing, libFuzzer generated many malformed inputs. The project frequently printed:

```text
Nije uspesno kreirana poruka: ...
```

because `MessageFactory::createMessage()` rejects unsupported or malformed message types.

![Generated fuzz inputs](libfuzzer/pictures/fuzz_inputs.png)

### Final statistics

The final run lasted approximately 31 seconds and produced:

```text
DONE   cov: 99 ft: 148 corp: 4/83b lim: 4096 exec/s: 15755 rss: 461Mb
Done 488435 runs in 31 second(s)

stat::number_of_executed_units: 488435
stat::average_exec_per_sec:     15755
stat::new_units_added:          4
stat::slowest_unit_time_sec:    0
stat::peak_rss_mb:              461
```

![libFuzzer final statistics](libfuzzer/pictures/final_stats.png)

No crash or AddressSanitizer error was reported during this run.

### Interpretation

The result does not prove that `MessageFactory` is free of defects. It shows that the selected fuzz target, seed corpus and approximately 30-second execution did not discover a crashing input or sanitizer-detected memory error.

The `cov` and `ft` values show that the fuzzer explored multiple code paths, while the corpus changed as new interesting inputs were discovered.

### Conclusion

libFuzzer successfully exercised `MessageFactory::createMessage()` with 488435 generated inputs.

No crash, buffer overflow, use-after-free or other AddressSanitizer-detected memory error was found during the final run. The parser tolerated a large amount of malformed input during the observed execution window.
