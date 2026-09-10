# UndefinedBehaviorSanitizer Analysis

## Description

UndefinedBehaviorSanitizer (UBSan) was used to detect undefined behavior during execution of the project's existing Catch2 test suite.

The project was compiled with:

```text
-fsanitize=undefined
-fno-omit-frame-pointer
```

UBSan stack traces were enabled using:

```text
UBSAN_OPTIONS=print_stacktrace=1
```

The analysis focused on runtime undefined behavior such as invalid enum values and other operations whose behavior is undefined in C++.

## Requirements

The following tools are required:

- CMake
- GCC/G++
- Qt 6
- UndefinedBehaviorSanitizer support in GCC

No separate UBSan package is required because sanitizer support is included in GCC.

## Running the analysis

From the `undefined_behavior_sanitizer` directory run:

```bash
./run_ubsan.sh
```

The script:

1. Removes the previous UBSan build directory.
2. Configures the project in Debug mode.
3. Enables UndefinedBehaviorSanitizer instrumentation.
4. Builds the project.
5. Runs the existing Catch2 test suite.
6. Stores the complete output in:

```text
results/ubsan.txt
```

7. Prints detected UBSan runtime errors in the terminal.

## Results

UBSan reported two runtime errors involving invalid values of the enum type `Color`.

### Invalid `Color` in `CreateGameResponse`

UBSan reported:

```text
src/common/message.cpp:95:27:
runtime error: load of value 836436083, which is not a valid value for type 'Color'
```

The affected code is:

```cpp
json["color"] = this->color;
```

Cppcheck had previously reported that `CreateGameResponse::color` is not initialized in one constructor.

This means UBSan observed the runtime consequence of the missing initialization: the program loaded a value that is not a valid `Color` enum member.

### Invalid `Color` in `BaseParticipant`

UBSan also reported:

```text
src/server/handlers.cpp:106:98:
runtime error: load of value 1936281120, which is not a valid value for type 'Color'
```

The affected code is:

```cpp
return new PlayerReadyResponse(
    participant->color,
    false,
    "Niste povezani u partiju!"
);
```

Cppcheck had previously reported that `BaseParticipant::color` is not initialized in its constructor.

UBSan therefore confirms that the uninitialized member can later be read as an invalid enum value during execution.

## Correlation with Cppcheck

The UBSan findings correlate directly with earlier Cppcheck warnings:

```text
Cppcheck:
- CreateGameResponse::color is not initialized
- BaseParticipant::color is not initialized

UBSan:
- message.cpp:95 loads an invalid Color value
- handlers.cpp:106 loads an invalid Color value
```

Cppcheck identifies the missing initialization statically, while UBSan observes the invalid value dynamically at runtime.

## Screenshots

```text
undefined_behavior_sanitizer/
├── README.md
├── run_ubsan.sh
├── results/
│   └── ubsan.txt
└── pictures/
    ├── run_ubsan.png
    ├── invalid_color_message.png
    └── invalid_color_participant.png
```

## Conclusion

UndefinedBehaviorSanitizer detected two project-specific runtime errors caused by invalid values of the `Color` enum.

The first occurs when `CreateGameResponse::color` is read in `message.cpp`, and the second occurs when `BaseParticipant::color` is used in `handlers.cpp`.

Both members had already been identified by Cppcheck as uninitialized, which strengthens the conclusion that these are real defects rather than isolated tool warnings.
