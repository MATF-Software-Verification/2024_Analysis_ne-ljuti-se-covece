# Clang-Tidy Analysis

## Description

Clang-Tidy was used to perform static analysis of the C++ source code in `src/common`, `src/server` and `src/game`.

## Requirements

- CMake
- GCC/G++
- Qt 6
- Clang-Tidy

Install on Ubuntu:

```bash
sudo apt update
sudo apt install clang-tidy
```

Used version:

```text
Ubuntu LLVM version 18.1.3
```

## Running the analysis

From the `clang_tidy` directory run:

```bash
./run_clang_tidy.sh
```

The script creates a clean build, enables `compile_commands.json`, builds the Qt project, runs Clang-Tidy over the project C++ files and stores the complete output in:

```text
results/clang_tidy.txt
```

## Results

Clang-Tidy reported four warnings in `src/game/client/handlers.cpp`.

### Possible null pointer dereference

```text
handlers.cpp:50:109: warning: Called C++ object pointer is null
[clang-analyzer-core.CallAndMessage]
```

The warning refers to:

```cpp
response->prepareMessage()
```

The analyzer found a path where `response` may be null before this call.

### Potential memory leaks

Three additional warnings were reported:

```text
handlers.cpp:76:9: warning: Potential memory leak
handlers.cpp:103:9: warning: Potential memory leak
handlers.cpp:130:9: warning: Potential memory leak
```

They are related to dynamically allocated `QWidget` objects passed to `QMessageBox` calls, for example:

```cpp
QMessageBox::information(new QWidget(), ...);
QMessageBox::critical(new QWidget(), ...);
```

These are documented as potential leaks, not confirmed defects, because Qt object ownership and lifetime would require additional analysis.

## Screenshots

Suggested structure:

```text
clang_tidy/
├── README.md
├── run_clang_tidy.sh
├── results/
│   └── clang_tidy.txt
└── pictures/
    ├── run_clang_tidy.png
    ├── null_pointer_warning.png
    └── memory_leaks.png
```

## Conclusion

The strongest finding is the possible null pointer dereference in `handlers.cpp:50`. Clang-Tidy also identified three potential memory leaks related to dynamically allocated `QWidget` objects.
