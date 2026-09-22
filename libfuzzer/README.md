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
#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <memory>

#include <QByteArray>

#include "messagefactory.h"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    QByteArray input(
        reinterpret_cast<const char*>(data),
        static_cast<qsizetype>(size)
    );

    std::unique_ptr<Message> message;
    try
    {
        message.reset(MessageFactory::createMessage(input));
    }
    catch (const std::runtime_error&)
    {
        // Rejecting arbitrary input is expected; continue with the next input.
        return 0;
    }

    // Failure to parse our own serialized message must not be swallowed.
    const QByteArray serialized = message->prepareMessage();
    std::unique_ptr<Message> reparsed(MessageFactory::createMessage(serialized));

    return 0;
}
```

The original harness only parsed and deleted a message. The current harness also
serializes it with `prepareMessage()` and parses that output again. Only the
first parse catches `std::runtime_error`: rejection of arbitrary input is
expected. Serialization and second-parse exceptions are left visible to the
fuzzer. `std::unique_ptr` provides automatic ownership for both messages.
No equality with the original input is required: extra fields may be ignored
and values normalized. This checks reparsability, not semantic equivalence.

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

Sixteen named JSON seeds were subsequently added in the same `corpus/`
directory, providing a seed for each of the 17 recognized message types.
The existing seeds were preserved. libFuzzer also adds generated corpus entries.
The expanded-corpus completed run reused mutations from an earlier attempt
whose final LeakSanitizer check failed because of the sandbox environment;
that attempt's log and empty crash artifact were removed. The corpus is thus
evolved, not a frozen set of only the 17 hand-written seeds.

## Running the analysis

From the `libfuzzer` directory run:

```bash
./run_libfuzzer.sh results/libfuzzer_new.txt
```

The script:

1. Removes the previous fuzz build.
2. Configures the project with Clang.
3. Builds the `common` library with fuzzing instrumentation.
4. Compiles `fuzz_messagefactory.cpp`.
5. Runs libFuzzer for approximately 30 seconds.
6. Stores the complete output in:

```text
results/libfuzzer_new.txt
```

The optional argument selects the report path and refuses to overwrite it.
Without an argument, the script retains its historical behavior and overwrites
`results/libfuzzer.txt`; use a new filename to preserve archived results.

## Results

The original archived run (`results/libfuzzer.txt`, parse/delete harness)
completed without a reported crash or AddressSanitizer error. The figures below
are taken from that saved log; earlier README figures referred to a different
execution and have been corrected. Historical screenshots are retained.

```text
DONE   cov: 99 ft: 148 corp: 4/83b lim: 4096 exec/s: 15805 rss: 461Mb
Done 489974 runs in 31 second(s)

stat::number_of_executed_units: 489974
stat::average_exec_per_sec:     15805
stat::new_units_added:          0
stat::slowest_unit_time_sec:    0
stat::peak_rss_mb:              461
```

During the run, libFuzzer generated many malformed inputs. The project frequently printed:

```text
Nije uspesno kreirana poruka: ...
```

This output is expected because `MessageFactory::createMessage()` explicitly rejects unknown or malformed message types.

No crash, buffer overflow, use-after-free or other AddressSanitizer failure was observed during this 30-second run.

### Comparison of saved experiments

| Saved report in `results/` | Harness and corpus | Executions | Seconds | cov | ft |
|---|---|---:|---:|---:|---:|
| `libfuzzer.txt` | Original parse/delete, original corpus | 489,974 | 31 | 99 | 148 |
| `libfuzzer_expanded_verified.txt.gz` | Same parse/delete, expanded and evolved corpus | 851,054 | 31 | 199 | 353 |
| `libfuzzer_roundtrip.txt.gz` | Parse/serialize/reparse, expanded and evolved corpus | 758,953 | 31 | 343 | 560 |

The two supplementary runs completed with exit status 0 and no reported
AddressSanitizer/LeakSanitizer error. The round-trip run reported 24,482
executions/s, 12 new units and peak RSS 465 MB. It used the existing script with
`./run_libfuzzer.sh results/libfuzzer_roundtrip.txt`, outside the sandbox so
LeakSanitizer could perform its final check. Historical logs were preserved.
The two supplementary logs are archived as lossless `.txt.gz` files to fit
repository file-size limits. The command above originally produced plain text;
compression was performed afterward. Read the archived reports with
`gzip -cd <report.txt.gz> | less`.

The corpus continued evolving between runs; these are not controlled throughput
benchmarks. `cov` and `ft` are internal counters, not percentages or proof that
all branches of all 17 constructors were executed. The round-trip harness adds
operations and instrumentation, so its counters are not directly comparable as
a percentage improvement over the original harness. No failure to reparse a
serialized message was observed in this execution window. This does not prove
semantic equivalence, valid game state, or absence of uninitialized-value use:
the enabled AddressSanitizer is not a general uninitialized-read detector.

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
│   ├── libfuzzer.txt
│   ├── libfuzzer_expanded_verified.txt.gz
│   └── libfuzzer_roundtrip.txt.gz
└── pictures/
    ├── run_libfuzzer.png
    ├── fuzz_inputs.png
    └── final_stats.png
```

## Conclusion

libFuzzer successfully exercised `MessageFactory::createMessage()` with hundreds of thousands of generated inputs.

In the original archived 31-second run, 489974 inputs were executed at an average rate of 15805 executions per second.

No crash or AddressSanitizer-detected memory error was found during this run. Unknown message types and malformed JSON are rejected with the expected
`std::runtime_error`. Recognized types with missing or invalid fields may still
be accepted; for example, `CreateGameMessage` does not explicitly validate
`numberOfPlayers`. The harness does not test game rules or server handlers.
