# Analysis of the "Ne ljuti se čoveče" Project

This GitHub repository contains an independent practical project completed for the **Software Verification** course at the Master's studies of the Faculty of Mathematics, University of Belgrade.

The project focuses on applying static and dynamic software verification tools and techniques to an existing open-source student project.

**Author: Marija Božić 1044/2023**

## Analyzed project

The analyzed project is an implementation of the board game **"Ne ljuti se čoveče"**, developed in C++ using the Qt framework.

The project contains:

1. common classes and communication messages,
2. a server-side application,
3. a client-side game application,
4. an existing Catch2 test suite.

Original project:

[GitLab repository](https://gitlab.com/matf-bg-ac-rs/course-rs/projects-2023-2024/ne-ljuti-se-covece/)

The analysis was performed on branch:

```text
main
```

at commit:

```text
b50bedc6240d0f02dba7c2fed278bbcf3b80900d
```

The analyzed project is included in this repository as a Git submodule.

## Tools and techniques

The following tools and techniques were used:

1. **Valgrind Memcheck**  
   Dynamic memory analysis used to detect uninitialized values, invalid memory usage and memory leaks.

2. **Clang-Tidy**  
   Static analysis of the C++ source code.

3. **Cppcheck**  
   Static analysis focused on warnings, uninitialized members and potential defects.

4. **AddressSanitizer**  
   Dynamic analysis of memory errors and memory leaks.

5. **libFuzzer**  
   Coverage-guided fuzz testing of `MessageFactory::createMessage()` using automatically generated and mutated inputs.

6. **UndefinedBehaviorSanitizer**  
   Dynamic detection of undefined behavior, including invalid values of the `Color` enum type.

7. **Lizard**  
   Static code-complexity analysis focused on cyclomatic complexity, function size and related structural metrics.

The existing Catch2 tests from the analyzed project were used as execution scenarios for some of the dynamic tools, but they are not counted as a separate verification technique in this project.

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       ├── gate.yml
│       └── tickets.yml
├── address_sanitizer/
├── clang_tidy/
├── cppcheck/
├── libfuzzer/
├── lizard/
├── ne-ljuti-se-covece/
├── undefined_behavior_sanitizer/
├── valgrind/
├── .gitignore
├── .gitmodules
├── README.md
└── ProjectAnalysisReport.md
```

Each tool directory contains the corresponding analysis results, a reproducibility script and additional documentation and screenshots where applicable.

## Running the analyses

Each tool can be executed from its own directory.

Valgrind Memcheck:

```bash
cd valgrind
./run_valgrind.sh
```

Clang-Tidy:

```bash
cd clang_tidy
./run_clang_tidy.sh
```

Cppcheck:

```bash
cd cppcheck
./run_cppcheck.sh
```

AddressSanitizer:

```bash
cd address_sanitizer
./run_asan.sh
```

libFuzzer:

```bash
cd libfuzzer
./run_libfuzzer.sh
```

UndefinedBehaviorSanitizer:

```bash
cd undefined_behavior_sanitizer
./run_ubsan.sh
```

Lizard:

```bash
cd lizard
./run_lizard.sh
```

Detailed instructions and results are available in the `README.md` file inside each tool directory.

## Main findings

The analysis revealed several relevant issues and structural characteristics in the project, including:

- use of the uninitialized `TurnContext::currentPlayerColor`,
- uninitialized members such as `CreateGameResponse::color` and `BaseParticipant::color`,
- a possible null pointer dereference in client-side code,
- potential memory-management issues,
- invalid values of the `Color` enum detected by UndefinedBehaviorSanitizer,
- several functions with relatively high cyclomatic complexity.

Multiple tools independently pointed to related problems. For example, Cppcheck statically detected uninitialized `Color` members, while UndefinedBehaviorSanitizer showed that these members can actually be read with invalid values at runtime.

Valgrind Memcheck additionally detected runtime use of an uninitialized value in logic related to `TurnContext::currentPlayerColor`.

In the final fuzzing run, libFuzzer executed hundreds of thousands of inputs against `MessageFactory::createMessage()` without finding a crash or an AddressSanitizer-detected memory error.

Lizard analyzed 37 files and 293 functions and reported three functions above its default cyclomatic-complexity warning threshold:

```text
Board::isPawnMoveValid                         CCN 19
MessageFactory::createMessage                  CCN 18
ActivateMagicMessageHandler::handleMessage     CCN 16
```

This result is particularly relevant for `MessageFactory::createMessage()`, which was also selected as the libFuzzer target.

## Report

A detailed description of all tools, results and conclusions is available in:

[ProjectAnalysisReport.md](ProjectAnalysisReport.md)
