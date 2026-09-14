# Project Analysis Report

## Valgrind Memcheck

### Tool

Valgrind Memcheck was used for dynamic memory analysis. The existing Catch2 test executable from the analyzed project was used as the execution scenario.

The analysis can be reproduced using:

```bash
cd valgrind
./run_valgrind.sh
```

The script creates a dedicated Debug build and runs the test executable using:

```text
--tool=memcheck
--leak-check=full
--show-leak-kinds=all
--track-origins=yes
```

The complete output is stored in:

```text
valgrind/results/memcheck.txt
```

### Test behavior under Memcheck

Under normal execution, the existing Catch2 tests passed successfully.

Under Memcheck, `ActivateMagicMessageHandlerTest` exhibited unstable behavior and failed, while Valgrind reported use of uninitialized values.

### Project-specific finding

An important report was:

```text
Conditional jump or move depends on uninitialised value(s)
```

The stack trace included:

```text
ActivateMagicMessageHandler::handleMessage()
GameManager::isMagicAvailable()
Board::getPlayer()
```

Additional reports showed:

```text
Use of uninitialised value of size 8
```

in `Board::getPlayer(Color)`.

Inspection of the source code showed that `TurnContext::currentPlayerColor` is not initialized in `TurnContext::reset()`, although the other state fields are initialized.

This value later participates in logic that determines the current player.

### Leak analysis

Memcheck also reported memory leaks in multiple categories:

```text
definitely lost
indirectly lost
possibly lost
still reachable
```

A significant number of leak records passed through Qt, Wayland, GTK and other system libraries. Those records were not automatically attributed to the analyzed project.

The strongest project-specific Valgrind result is therefore the use of an uninitialized value.

### Conclusion

Valgrind Memcheck detected runtime use of an uninitialized value related to `TurnContext::currentPlayerColor`. The finding is relevant because the uninitialized value propagates into player-selection logic and affects runtime behavior.

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

The project is configured with:

```text
CMAKE_EXPORT_COMPILE_COMMANDS=ON
```

so that Clang-Tidy can use the generated `compile_commands.json` database.

The complete result is stored in:

```text
clang_tidy/results/clang_tidy.txt
```

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

The analyzer determined that an execution path can reach this expression while `response` is null.

### Potential memory leaks

Clang-Tidy also reported three potential memory leak warnings in `handlers.cpp`, related to dynamically allocated `QWidget` objects passed to `QMessageBox`.

### Conclusion

Clang-Tidy found four project-specific warnings. The strongest result is a potential null pointer dereference in the client-side handler code.

---

## Cppcheck

### Tool

Cppcheck was used for static analysis with focus on warnings, portability and performance issues.

The analysis can be reproduced using:

```bash
cd cppcheck
./run_cppcheck.sh
```

The analyzed directories are:

```text
src/common
src/server
src/game
```

The complete output is stored in:

```text
cppcheck/results/cppcheck.txt
```

### Uninitialized members

Cppcheck reported multiple uninitialized member variables, including:

```text
CreateGameResponse::color
Response::broadcast
ActivateMagicResponse::remainingMagicNumber
ActivateMagicResponse::newDiceNumber
TurnContext::currentPlayerColor
BaseParticipant::gameManager
BaseParticipant::color
ServerThreadParticipant::socket
Client::color
```

### Important correlation

The finding for:

```text
TurnContext::currentPlayerColor
```

correlates with the Valgrind Memcheck result.

Cppcheck identified the missing initialization statically, while Valgrind showed runtime use of an uninitialized value in the same area of the program.

### Conclusion

Cppcheck detected several uninitialized members. Its results are especially useful because later dynamic analysis confirmed that some of these values are actually used at runtime.

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

### Full test suite behavior

The complete existing Catch2 test suite did not finish under AddressSanitizer.

Execution aborted in `ActivateMagicMessageHandlerTest` after Qt reported:

```text
ASSERT failure in QList::at: "index out of range"
```

The process then terminated with `SIGABRT`.

To obtain a LeakSanitizer report, the test was executed again while excluding:

```text
ActivateMagicMessageHandlerTest
```

using the Catch2 filter:

```text
~ActivateMagicMessageHandlerTest
```

### LeakSanitizer result

The filtered execution reported:

```text
SUMMARY: AddressSanitizer: 198924 byte(s) leaked in 2953 allocation(s).
```

The inspected direct leak traces were located primarily in external Qt/Wayland infrastructure.

Some indirect leak traces passed through project code:

```text
Square::Square(QString, QObject*)       src/server/square.cpp:4
Board::initializeTable()                src/server/board.cpp:243
Board::Board(int, QObject*)             src/server/board.cpp:5
```

Because these were indirect leak traces, they do not by themselves prove that `Square` or `Board` are the root cause.

### Conclusion

AddressSanitizer revealed unstable behavior in `ActivateMagicMessageHandlerTest` and LeakSanitizer reported retained allocations. The direct leak traces inspected were mainly located in external libraries, while some indirect traces included project objects.

---

## libFuzzer

### Tool

LLVM libFuzzer was used to fuzz:

```cpp
MessageFactory::createMessage(QByteArray)
```

This function was selected because it parses incoming message data and therefore represents a useful input boundary for fuzzing.

The analysis can be reproduced using:

```bash
cd libfuzzer
./run_libfuzzer.sh
```

### Fuzz target

The custom fuzz target is located in:

```text
libfuzzer/fuzz_messagefactory.cpp
```

For every generated input, it:

1. converts the byte buffer into `QByteArray`,
2. calls `MessageFactory::createMessage()`,
3. deletes a successfully created message,
4. catches the expected `std::runtime_error` for malformed or unknown message types.

Invalid message types are expected fuzz inputs and are therefore not treated as crashes.

### Instrumentation

The `common` library was built with:

```text
-fsanitize=fuzzer-no-link,address
-fno-omit-frame-pointer
```

The final fuzz target was linked with:

```text
-fsanitize=fuzzer,address
```

This enables libFuzzer coverage-guided mutation together with AddressSanitizer checks.

### Final statistics

The final fuzzing run lasted approximately 31 seconds:

```text
DONE   cov: 99 ft: 148 corp: 4/83b lim: 4096 exec/s: 15755 rss: 461Mb
Done 488435 runs in 31 second(s)

stat::number_of_executed_units: 488435
stat::average_exec_per_sec:     15755
stat::new_units_added:          4
stat::peak_rss_mb:              461
```

No crash or AddressSanitizer error was reported during the final run.

The `cov: 99` value is a libFuzzer coverage counter and should not be interpreted as 99 percent line coverage.

### Conclusion

libFuzzer exercised `MessageFactory::createMessage()` with hundreds of thousands of generated inputs. No crashing input or sanitizer-detected memory error was discovered during the final execution window.

---

## UndefinedBehaviorSanitizer

### Tool

UndefinedBehaviorSanitizer (UBSan) was used to detect undefined behavior during runtime execution of the existing Catch2 tests.

The project was compiled with:

```text
-fsanitize=undefined
-fno-omit-frame-pointer
```

Stack traces were enabled with:

```text
UBSAN_OPTIONS=print_stacktrace=1
```

The analysis can be reproduced using:

```bash
cd undefined_behavior_sanitizer
./run_ubsan.sh
```

The complete output is stored in:

```text
undefined_behavior_sanitizer/results/ubsan.txt
```

### Invalid enum value in CreateGameResponse

UBSan reported:

```text
src/common/message.cpp:95:27:
runtime error: load of value 836436083, which is not a valid value for type 'Color'
```

The affected statement is:

```cpp
json["color"] = this->color;
```

Cppcheck had previously reported that `CreateGameResponse::color` is not initialized in one constructor.

UBSan therefore shows the runtime consequence of that missing initialization.

### Invalid enum value in BaseParticipant

UBSan also reported:

```text
src/server/handlers.cpp:106:98:
runtime error: load of value 1936281120, which is not a valid value for type 'Color'
```

The affected code uses:

```cpp
participant->color
```

when creating a `PlayerReadyResponse`.

Cppcheck had previously reported that `BaseParticipant::color` is not initialized in its constructor.

### Correlation with Cppcheck

The two tools support the same conclusion from different directions:

```text
Cppcheck:
- CreateGameResponse::color is not initialized
- BaseParticipant::color is not initialized

UBSan:
- message.cpp loads an invalid Color value
- handlers.cpp loads an invalid Color value
```

Cppcheck identifies the problem statically, while UBSan observes invalid values during actual execution.

### Conclusion

UndefinedBehaviorSanitizer detected two project-specific runtime errors involving invalid `Color` enum values. Both correlate directly with uninitialized members previously reported by Cppcheck.

---

## Overall conclusion

The six selected tools complement each other:

- Valgrind Memcheck and UBSan detected runtime use of invalid or uninitialized values.
- Cppcheck independently identified several missing member initializations.
- Clang-Tidy found a potential null pointer dereference and possible memory-management issues.
- AddressSanitizer exposed unstable runtime behavior and reported retained allocations.
- libFuzzer stress-tested the message parser using automatically generated inputs without discovering a crashing input in the final run.

The most important recurring theme across the analysis is missing initialization of state and enum-valued members. Several independent tools identified different manifestations of this problem, which increases confidence that these findings represent real defects in the analyzed project.
