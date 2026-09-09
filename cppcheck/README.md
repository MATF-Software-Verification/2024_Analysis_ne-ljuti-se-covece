# Cppcheck Analysis

## Description

Cppcheck was used to perform static analysis of the C++ source code with focus on warnings related to uninitialized members, portability and performance issues.

The analysis was run over the main project source directories:

```text
src/common
src/server
src/game
```

Cppcheck is used here as one of the tools that was not covered in the course exercises.

## Requirements

The following tools are required:

- Cppcheck
- C++17-compatible environment

Cppcheck can be installed on Ubuntu using:

```bash
sudo apt update
sudo apt install cppcheck
```

## Running the analysis

From the `cppcheck` directory run:

```bash
./run_cppcheck.sh
```

The script executes:

```bash
cppcheck   --enable=warning,performance,portability   --inconclusive   --std=c++17   --suppress=missingIncludeSystem   -Dslots=   ../ne-ljuti-se-covece/src/common   ../ne-ljuti-se-covece/src/server   ../ne-ljuti-se-covece/src/game
```

The `-Dslots=` option is used so that Cppcheck does not report Qt's `slots` macro as an unknown macro.

The complete output is stored in:

```text
results/cppcheck.txt
```

## Results

Cppcheck reported several warnings about class members that are not initialized in constructors.

### Uninitialized members in message classes

Examples include:

```text
CreateGameResponse::color
Response::broadcast
ActivateMagicResponse::remainingMagicNumber
ActivateMagicResponse::newDiceNumber
```

These warnings indicate that some object fields may contain indeterminate values until they are explicitly assigned.

### TurnContext::currentPlayerColor

Cppcheck reported:

```text
src/common/turncontext.cpp:3:14:
warning: Member variable 'TurnContext::currentPlayerColor'
is not initialized in the constructor. [uninitMemberVar]
```

This is particularly important because the same field was already identified by Valgrind Memcheck as being used while uninitialized.

The agreement between two independent tools strengthens the conclusion that this is a real project defect rather than a tool-specific false positive.

### Other uninitialized members

Additional warnings were reported for:

```text
BaseParticipant::gameManager
BaseParticipant::color
ServerThreadParticipant::socket
Client::color
```

These findings indicate other locations where object state may not be fully initialized immediately after construction.

## Screenshots

The screenshots are stored in:

```text
pictures/
```

Recommended structure:

```text
cppcheck/
├── README.md
├── run_cppcheck.sh
├── results/
│   └── cppcheck.txt
└── pictures/
    ├── run_cppcheck.png
    ├── uninitialized_members.png
    └── turncontext_warning.png
```

## Conclusion

Cppcheck found multiple warnings related to uninitialized member variables.

The strongest result is the warning for `TurnContext::currentPlayerColor`, because the same problem was also detected dynamically by Valgrind Memcheck.

Other warnings, such as uninitialized fields in response, participant and client classes, represent additional candidates for manual inspection and further testing.
