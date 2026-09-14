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

The complete output is stored in `valgrind/results/memcheck.txt`.

### Main finding

Valgrind reported use of uninitialized values in the execution path involving:

```text
ActivateMagicMessageHandler::handleMessage()
GameManager::isMagicAvailable()
Board::getPlayer()
```

Inspection of the source code showed that `TurnContext::currentPlayerColor` is not initialized in `TurnContext::reset()`, although the other state fields are initialized. The value later participates in player-selection logic.

Memcheck also reported multiple leak categories. A significant portion of the traces went through Qt, Wayland, GTK and other system libraries, so those reports were not automatically attributed to the analyzed project.

### Conclusion

The strongest project-specific Valgrind finding is runtime use of an uninitialized value related to `TurnContext::currentPlayerColor`.

---

## Clang-Tidy

### Tool

Clang-Tidy was used for static analysis of the C++ source code in `src/common`, `src/server` and `src/game`.

The analysis can be reproduced using:

```bash
cd clang_tidy
./run_clang_tidy.sh
```

The project is configured with `CMAKE_EXPORT_COMPILE_COMMANDS=ON` so that Clang-Tidy can use `compile_commands.json`.

### Findings

The most important warning was reported in `src/game/client/handlers.cpp:50`:

```text
Called C++ object pointer is null
[clang-analyzer-core.CallAndMessage]
```

The warning refers to:

```cpp
response->prepareMessage()
```

Clang-Tidy also reported three potential memory leak warnings related to dynamically allocated `QWidget` objects passed to `QMessageBox`.

### Conclusion

The strongest result is a potential null pointer dereference in client-side handler code.

---

## Cppcheck

### Tool

Cppcheck was used for static analysis with focus on warnings, portability and performance issues.

The analysis can be reproduced using:

```bash
cd cppcheck
./run_cppcheck.sh
```

### Findings

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

The `TurnContext::currentPlayerColor` finding correlates with Valgrind. Cppcheck identifies the missing initialization statically, while Valgrind shows runtime use of an uninitialized value in the same area of the program.

### Conclusion

Cppcheck detected several uninitialized members, some of which were later confirmed dynamically by other tools.

---

## AddressSanitizer

### Tool

AddressSanitizer was used for dynamic memory analysis with:

```text
-fsanitize=address
-fno-omit-frame-pointer
```

Leak detection was enabled using `ASAN_OPTIONS=detect_leaks=1`.

The analysis can be reproduced using:

```bash
cd address_sanitizer
./run_asan.sh
```

### Findings

The complete existing Catch2 test suite aborted in `ActivateMagicMessageHandlerTest` after Qt reported:

```text
ASSERT failure in QList::at: "index out of range"
```

To obtain a LeakSanitizer report, that test was excluded with the Catch2 filter:

```text
~ActivateMagicMessageHandlerTest
```

The filtered run reported:

```text
SUMMARY: AddressSanitizer: 198924 byte(s) leaked in 2953 allocation(s).
```

The inspected direct leak traces were located mainly in external Qt/Wayland infrastructure. Some indirect traces passed through `Square` and `Board`, but indirect traces alone do not prove that those project classes are the root cause.

### Conclusion

AddressSanitizer exposed unstable runtime behavior in `ActivateMagicMessageHandlerTest` and LeakSanitizer reported retained allocations.

---

## libFuzzer

### Tool

LLVM libFuzzer was used to fuzz:

```cpp
MessageFactory::createMessage(QByteArray)
```

The analysis can be reproduced using:

```bash
cd libfuzzer
./run_libfuzzer.sh
```

### Fuzz target

The custom fuzz target is `libfuzzer/fuzz_messagefactory.cpp`. For each generated input it converts the byte buffer into `QByteArray`, calls `MessageFactory::createMessage()`, deletes a successfully created message and catches the expected `std::runtime_error` for malformed or unknown message types.

The `common` library was built with:

```text
-fsanitize=fuzzer-no-link,address
-fno-omit-frame-pointer
```

and the final target was linked with:

```text
-fsanitize=fuzzer,address
```

### Results

The final run lasted approximately 31 seconds and executed 488435 inputs. The final statistics included:

```text
cov: 99
ft: 148
corp: 4/83b
exec/s: 15755
```

No crash or AddressSanitizer error was reported. `cov: 99` is a libFuzzer coverage counter and should not be interpreted as 99% line coverage.

### Conclusion

libFuzzer stress-tested the message parser with hundreds of thousands of generated inputs without discovering a crashing input during the final run.

---

## UndefinedBehaviorSanitizer

### Tool

UndefinedBehaviorSanitizer (UBSan) was used to detect undefined behavior during runtime execution of the existing Catch2 tests.

The project was compiled with:

```text
-fsanitize=undefined
-fno-omit-frame-pointer
```

Stack traces were enabled with `UBSAN_OPTIONS=print_stacktrace=1`.

The analysis can be reproduced using:

```bash
cd undefined_behavior_sanitizer
./run_ubsan.sh
```

### Findings

UBSan reported an invalid `Color` enum value in `src/common/message.cpp:95` at:

```cpp
json["color"] = this->color;
```

Cppcheck had previously reported that `CreateGameResponse::color` is not initialized in one constructor.

UBSan also reported an invalid `Color` enum value in `src/server/handlers.cpp:106` when `participant->color` is used to construct a `PlayerReadyResponse`.

Cppcheck had previously reported that `BaseParticipant::color` is not initialized in its constructor.

### Conclusion

UBSan detected two project-specific runtime errors involving invalid `Color` enum values. Both correlate directly with uninitialized members previously reported by Cppcheck.

---

## Overall conclusion

The six selected tools complement each other:

- Valgrind Memcheck and UBSan detected runtime use of invalid or uninitialized values.
- Cppcheck independently identified several missing member initializations.
- Clang-Tidy found a potential null pointer dereference and possible memory-management issues.
- AddressSanitizer exposed unstable runtime behavior and reported retained allocations.
- libFuzzer stress-tested the message parser using automatically generated inputs without discovering a crashing input in the final run.

The most important recurring theme across the analysis is missing initialization of state and enum-valued members. Several independent tools identified different manifestations of this problem, which increases confidence that these findings represent real defects in the analyzed project.
