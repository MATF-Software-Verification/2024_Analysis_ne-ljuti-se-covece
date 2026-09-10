# libFuzzer Analysis

## Description

LLVM libFuzzer was used to fuzz the message parsing logic implemented by `MessageFactory::createMessage(QByteArray)`.

The goal was to test how the parser behaves when it receives a large number of mutated and malformed inputs, including invalid JSON data, corrupted message types and arbitrary byte sequences.

The fuzz target is stored in:

```text
fuzz_messagefactory.cpp
```

and calls:

```cpp
MessageFactory::createMessage(input);
```

for each generated input.

## Requirements

The following tools are required:

- Clang/Clang++
- CMake
- Qt 6
- pkg-config
- libFuzzer support from Clang

The versions used during the analysis were:

```text
Ubuntu clang version 18.1.3
Qt6Core 6.4.2
```

If needed, the required packages can be installed using:

```bash
sudo apt update
sudo apt install clang pkg-config
```

## Fuzz target

The fuzz target converts the byte buffer supplied by libFuzzer into a `QByteArray` and passes it to `MessageFactory::createMessage()`.

```cpp
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    QByteArray input(
        reinterpret_cast<const char*>(data),
        static_cast<qsizetype>(size)
    );

    try
    {
        Message* message = MessageFactory::createMessage(input);
        delete message;
    }
    catch (const std::runtime_error&)
    {
        // Invalid or unknown message types are expected fuzz inputs.
    }

    return 0;
}
```

The `std::runtime_error` exception is caught because invalid or unknown message types are expected during fuzzing and should not be treated as crashes.

## Instrumented build

The `common` library is compiled using Clang and sanitizer instrumentation:

```text
-fsanitize=fuzzer-no-link,address
-fno-omit-frame-pointer
```

The final fuzz executable is linked using:

```text
-fsanitize=fuzzer,address
```

This allows libFuzzer to collect coverage information from the tested code and AddressSanitizer to detect memory errors during fuzzing.

## Corpus

The initial corpus contains simple seed inputs, including a valid-looking JSON message and an invalid text input.

Example:

```text
{"type":"CreateGameMessage","numberOfPlayers":4}
abc
```

libFuzzer then mutates the corpus automatically and keeps inputs that discover new execution paths.

## Running the analysis

From the `libfuzzer` directory run:

```bash
./run_libfuzzer.sh
```

The script:

1. Removes the previous fuzz build.
2. Configures the project with Clang.
3. Builds the `common` library with fuzzing instrumentation.
4. Compiles `fuzz_messagefactory.cpp`.
5. Runs libFuzzer for approximately 30 seconds.
6. Stores the complete output in:

```text
results/libfuzzer.txt
```

## Results

The final run completed without a crash or AddressSanitizer error.

```text
DONE   cov: 99 ft: 148 corp: 4/83b lim: 4096 exec/s: 15755 rss: 461Mb
Done 488435 runs in 31 second(s)

stat::number_of_executed_units: 488435
stat::average_exec_per_sec:     15755
stat::new_units_added:          4
stat::slowest_unit_time_sec:    0
stat::peak_rss_mb:              461
```

During the run, libFuzzer generated many malformed inputs. The project frequently printed:

```text
Nije uspesno kreirana poruka: ...
```

This output is expected because `MessageFactory::createMessage()` explicitly rejects unknown or malformed message types.

No crash, buffer overflow, use-after-free or other AddressSanitizer failure was observed during this 30-second run.

## Interpretation

The result does not prove that the parser is bug-free. It only shows that, for this fuzz target, corpus and execution time, libFuzzer did not discover an input that caused a crash or sanitizer-detected memory error.

The final coverage counters indicate that the fuzzer explored multiple code paths:

```text
cov: 99
ft: 148
```

The corpus was also updated during fuzzing as new interesting inputs were discovered.

## Screenshots

```text
libfuzzer/
├── README.md
├── run_libfuzzer.sh
├── fuzz_messagefactory.cpp
├── corpus/
├── results/
│   └── libfuzzer.txt
└── pictures/
    ├── run_libfuzzer.png
    ├── fuzz_inputs.png
    └── final_stats.png
```

## Conclusion

libFuzzer successfully exercised `MessageFactory::createMessage()` with hundreds of thousands of generated inputs.

In the final 31-second run, 488435 inputs were executed at an average rate of 15755 executions per second.

No crash or AddressSanitizer-detected memory error was found during this run. The parser handled malformed input by rejecting it and throwing the expected `std::runtime_error`, which the fuzz harness catches intentionally.
