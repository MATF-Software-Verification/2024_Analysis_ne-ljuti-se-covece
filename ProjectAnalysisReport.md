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

`TurnContext::reset()` initializes:

```text
remainingNumberOfMoves
remainingNumberOfRolles
lastRolledValue
numberOfMagics
```

but does not initialize:

```cpp
currentPlayerColor
```

The value is later returned by `getCurrentPlayerColor()` and is ultimately used in:

```cpp
return this->players[color];
```

inside `Board::getPlayer()`.

![Uninitialized value reported by Memcheck](valgrind/pictures/uninitialized_value.png)

### Other Valgrind findings

Valgrind also reported invalid reads and memory leaks in Qt/Wayland/GTK-related code. These were not attributed directly to the analyzed project because their stack traces were located in external libraries.

### Memcheck summary

![Valgrind Memcheck summary](valgrind/pictures/memcheck_summary.png)

### Conclusion

Valgrind Memcheck detected a project-specific use of an uninitialized value. The field `TurnContext::currentPlayerColor` is not initialized by the constructor or by `TurnContext::reset()`, but it is later used by the game logic.

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

The analyzer determined that the execution path can reach this expression while `response` is null. Dereferencing a null pointer may cause the application to crash.

![Null pointer warning](clang_tidy/pictures/null_pointer_warning.png)

### Potential memory leaks

Clang-Tidy also reported three potential memory leaks:

```text
handlers.cpp:76
handlers.cpp:103
handlers.cpp:130
```

The warnings are related to dynamically allocated `QWidget` objects passed to `QMessageBox` calls, for example:

```cpp
QMessageBox::information(new QWidget(), ...);
QMessageBox::critical(new QWidget(), ...);
```

These findings are treated as potential leaks rather than confirmed defects because Qt object ownership and lifetime would require additional analysis.

![Potential memory leak warnings](clang_tidy/pictures/memory_leaks.png)

### Conclusion

Clang-Tidy found four project-specific warnings. The strongest finding is a possible null pointer dereference in `src/game/client/handlers.cpp`. Three additional warnings indicate possible memory leaks associated with dynamically allocated `QWidget` objects.
