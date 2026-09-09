# Valgrind Memcheck analysis

## Description

Valgrind Memcheck was used to analyze the project for memory-related problems such as:

- use of uninitialized values
- invalid memory reads and writes
- memory leaks

The analysis was performed on the existing Catch2 test executable in order to exercise a significant part of the project logic in a reproducible way.

## Requirements

The following tools are required:

- CMake
- GCC/G++
- Qt 6
- Valgrind

Valgrind can be installed on Ubuntu using:

```bash
sudo apt update
sudo apt install valgrind
```

## Running the analysis

From the `valgrind` directory run:

```bash
./run_valgrind.sh
```

The script:

1. Removes the previous Valgrind build directory.
2. Configures the project in Debug mode.
3. Builds the project.
4. Runs the Catch2 test executable under Valgrind Memcheck.
5. Stores the full Memcheck report in `results/memcheck.txt`.
6. Prints the final part of the report in the terminal.

The Memcheck invocation uses:

```bash
valgrind \
  --tool=memcheck \
  --leak-check=full \
  --show-leak-kinds=all \
  --track-origins=yes
```

## Results

Valgrind reported memory-related issues, including:

- conditional branches depending on uninitialized values
- use of an uninitialized value
- invalid reads in Qt/Wayland shutdown code
- memory leaks reported by external Qt/Wayland/GTK libraries

The most important project-specific finding was related to `TurnContext::currentPlayerColor`.

`TurnContext::reset()` initializes:

- `remainingNumberOfMoves`
- `remainingNumberOfRolles`
- `lastRolledValue`
- `numberOfMagics`

but does not initialize:

```cpp
currentPlayerColor
```

The uninitialized value is later read through:

```cpp
getCurrentPlayerColor()
```

and is used by:

```text
ActivateMagicMessageHandler::handleMessage()
GameManager::isMagicAvailable()
Board::getPlayer()
```

`Board::getPlayer()` uses the value directly as an index:

```cpp
return this->players[color];
```

While running under Valgrind, one existing Catch2 test case also became unstable:

- 15 test cases
- 14 passed
- 1 failed
- 303 assertions
- 301 passed
- 2 failed

The failing assertions were located in `ActivateMagicMessageHandlerTest`.

## Interpretation

The analysis indicates that `currentPlayerColor` may be read before it has been assigned a valid value.

This is a project-level issue because the value influences control flow and is later used to index the player container.

Some other Valgrind findings, especially invalid reads and leak reports originating in Qt/Wayland/GTK libraries, were not attributed directly to the project source code.

## Results and screenshots

The full Valgrind output is stored in:

```text
results/memcheck.txt
```

Screenshots for the analysis can be stored in:

```text
pictures/
```

Suggested screenshots:

```text
pictures/
├── run_valgrind.png
├── failed_test.png
├── uninitialized_value.png
└── memcheck_summary.png
```

## Conclusion

Valgrind Memcheck successfully detected a project-specific use of an uninitialized value.

The root cause is that `TurnContext::currentPlayerColor` is not initialized by the constructor or by `TurnContext::reset()`. The value is later propagated into game logic and used by `Board::getPlayer()`.

The finding demonstrates that the project can behave differently under instrumented execution and that initialization of the current player state should be made explicit before the value is used.
