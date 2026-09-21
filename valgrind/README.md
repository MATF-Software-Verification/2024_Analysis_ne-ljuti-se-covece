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

The default invocation (or `./run_valgrind.sh tests`) runs the original test analysis. It is not necessary to repeat it to inspect the archived findings.

The script in test mode:

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

## Additional investigation: where do the existing leaks come from?

The archived `results/memcheck.txt` was produced by the **test executable**, not
by standalone server/client gameplay. The totals describe that entire process:

| Category | Bytes | Blocks |
|---|---:|---:|
| Definitely lost | 10,320 | 158 |
| Indirectly lost | 202,954 | 3,000 |
| Possibly lost | 4,800 | 10 |
| Still reachable | 2,861,521 | 32,786 |

### Concrete leaks caused by test cleanup

1. In [messageParsingTest.cpp](../ne-ljuti-se-covece/src/test/common/messageParsingTest.cpp),
   the section beginning at line 119 allocates `StartGameMessage` at line 121
   and a second message through the factory at line 123. Neither is deleted.
   The existing log's loss record **9,792** identifies the allocation at line 121:

   ```text
   136 (16 direct, 120 indirect) bytes in 1 blocks are definitely lost
   operator new -> test function (messageParsingTest.cpp:121)
   ```

   The test owns these unparented objects. This record demonstrates missing
   test cleanup, not a leak caused by Catch2 or by the factory retaining objects.
   Other parsing sections use the same allocation-without-deletion pattern.

2. In [boardTest.cpp](../ne-ljuti-se-covece/src/test/boardTest.cpp), line 35 creates
   `new Board(4)` and the section ends without deleting it. Its existing loss
   record identifies **23,728 bytes (88 direct, 23,640 indirect)** and the
   allocation at `boardTest.cpp:35`. The lost top-level Board is a test lifetime
   problem; its dependent allocations account for the indirect portion.

These examples establish that **some reported leaks originate in the tests**.
They do not classify every byte in the summary. A Catch2 frame only identifies
who called the test. A Qt allocation frame can belong to an object whose lifetime
is the responsibility of the test or production code.

### Separate production ownership questions

Manual inspection also finds that `GameManager` allocates its socket, turn
context and board without parents or explicit cleanup; `Board` and `Player`
likewise allocate objects without complete ownership/cleanup. Deleting a raw
pointer container does not delete its pointees. Therefore simply deleting Board
in a test would not establish that all internal production allocations are freed.
These ownership issues must be distinguished from the test's lost root object.

The Qt/Wayland shutdown invalid-read records are separate platform candidates.
Their library stack traces do not justify assigning all leak records to Qt.
Use the allocation stack, the expected owner and the scenario together.

- **Definitely lost:** no pointer to the allocation is found; investigate who
  lost ownership.
- **Indirectly lost:** only reachable through other lost allocations; investigate
  the lost root first.
- **Possibly lost:** an interior pointer occurs in the reachability chain;
  additional investigation is needed.
- **Still reachable:** reachable from a root, so not automatically a leak; may
  still include unnecessarily retained objects or caches.

The uninitialized-color finding is not a memory-leak finding. The magic tests
usually set the participant color but omit the current turn color. The normal
successful start-game handler explicitly sets it. Memcheck confirms the unsafe
read in the test scenario; this alone does not prove failure in every normally
started game.

## Additional investigation: standalone server and client

The standalone experiment below was executed with one server and two clients.
The original tests were not rerun for this supplement.
All new files go directly in the existing `results/` directory.

From `valgrind/`, build just the applications once, before launching processes:

```bash
./run_valgrind.sh build
```

This builds the production `common` library, server and client in Debug mode.
It does not build/run the test target. Do not run the default test mode or rebuild
while the server/clients are using this build directory.

Actual executable paths, relative to this directory:

```text
../ne-ljuti-se-covece/build-valgrind/src/server/server
../ne-ljuti-se-covece/build-valgrind/src/game/game
```

Both applications use QApplication. Run the following commands from terminals
inside your graphical desktop session, using the same Qt backend as the original
measurement when comparing platform-related findings. The script does not force
an offscreen backend. Server and client use **localhost:12345**; neither implements
application arguments for configuring the address/port.

Terminal 1, in `valgrind/`:

```bash
./run_valgrind.sh server
```

Wait until `results/server_output.txt` contains `Server started! Listening...`.
If it says `Server could not start!`, stop and resolve the port/listen problem;
the application can remain running even when listening fails. Do not run the
Catch2 tests concurrently: they instantiate the same server on the same port.

Terminal 2, in `valgrind/`:

```bash
./run_valgrind.sh client
```

Terminal 3, in `valgrind/`:

```bash
./run_valgrind.sh client2
```

`client2` runs a second copy of the same game executable with different log names.

### Manual scenario

1. In client 1 create a game for **two human players**; the server adds two bots.
2. Copy the generated game code and join from client 2.
3. Mark client 2 ready; start the game from client 1.
4. Play several turns: roll, move a pawn when possible, and end the turn.
5. Activate an available magic and try one operation that should be rejected.
6. Close both clients and wait for their processes and reports to finish.
7. Interrupt the server with Ctrl+C in its terminal.

Record the actions/number of turns, versions, Qt backend, and termination method
alongside the interpretation in this README. Random dice rolls mean this is a
repeatable procedure, not a guarantee of identical execution or byte counts.
If the application crashes or hangs, record the incomplete scenario as such.

The server has **no graceful application shutdown command**. Ctrl+C ends the
process without proving that its cleanup/destructors ran. Label that report as
memory state at interruption, not as a completed graceful-cleanup test. Adding
graceful thread and object cleanup would be a separate production-code change.

### Saved files and comparison

| Process | Memcheck report | Application output | Exit status |
|---|---|---|---|
| Original tests (archived) | `results/memcheck.txt` | Historical screenshots | Not recorded by original script |
| Server | `results/memcheck_server.txt` | `results/server_output.txt` | `results/server_exit_code.txt` |
| Client 1 | `results/memcheck_client.txt` | `results/client_output.txt` | `results/client_exit_code.txt` |
| Client 2 | `results/memcheck_client2.txt` | `results/client2_output.txt` | `results/client2_exit_code.txt` |

Application modes refuse to overwrite existing results. Archive a previous
measurement deliberately before repeating it. Status 97 means Memcheck detected
errors (including definite/possible leaks); other failures/signals can also give
nonzero statuses. This is a combined process/tool status; inspect both logs.
Hard termination such as SIGKILL need not produce complete reports/status files.

For each important allocation stack, compare the test, server and client reports:

- A direct allocation in a test source belongs to that test scenario.
- A matching production allocation in a standalone process establishes that it
  also occurs without Catch2; ownership and termination still determine whether
  it is an actual leak.
- Repeatedly retained games may remain reachable via the server singleton and
  still represent unwanted memory growth.
- Library-only reports need a minimal Qt/control or backend comparison before
  attributing responsibility; do not suppress all Qt frames.

Do not subtract aggregate byte totals and call the difference production leakage.
These processes have different lifetimes, inputs and allocation graphs. Absence
of a finding only applies to the executed paths.

### Recorded gameplay results

The second attempt reached the game board on both clients (blue and yellow,
with red and green bots). The user played several turns, closed both client
windows and then interrupted the server with Ctrl+C. Application logs contain
roll, move and end-turn responses. This records a gameplay session, not a full
game completed to victory; its exact duration and turn count were not recorded.
The logs identify Valgrind 3.22.0 and Qt 6.4.2, with Wayland frames.

Files without a suffix contain this session. Files ending in `_attempt1.txt`
belong to the earlier interrupted attempt and are not included in these totals.

| Process | Definitely lost (bytes/blocks) | Indirectly lost (bytes/blocks) | Possibly lost (bytes/blocks) | Still reachable (bytes/blocks) | Errors/contexts | Exit status |
|---|---:|---:|---:|---:|---:|---:|
| Server | 76,504 / 937 | 207,390 / 2,352 | 11,096 / 21 | 2,699,592 / 25,585 | 117 / 73 | 130 |
| Client 1 | 16,904 / 149 | 877 / 11 | 3,520 / 8 | 557,284,426 / 31,177 | 40 / 40 | 97 |
| Client 2 | 14,936 / 129 | 1,484 / 11 | 3,584 / 8 | 557,195,889 / 31,120 | 38 / 38 | 97 |

Both clients produced complete Memcheck summaries after their windows were
closed. Status 97 is the configured Memcheck error status, not evidence by
itself of a crash. Server status 130 corresponds to interruption; its totals
are not a measurement of graceful server cleanup. The large client reachable
category must not be presented as hundreds of megabytes of confirmed leakage.

**Concrete production leaks, independent of test cleanup:**

- Server loss record **7,551** in `results/memcheck_server.txt` reports
  **336 bytes (96 direct, 240 indirect)** in two blocks allocated by
  `MessageFactory::createMessage` (`messagefactory.cpp:31`), called from
  `Bot::sendMessage` (`participants.cpp:130`). The parsed response is not
  deleted after `generateNextMove`. The inner variable also named `response`
  is a different object; passing that object to `sendResponse` does not free
  the outer parsed response. This lifetime defect occurs in actual bot play.
- Server loss record **7,691** reports **568 bytes (32 direct, 536 indirect)**
  allocated at `BaseParticipant::sendResponse` (`participants.cpp:17`). This
  creates an unparented `BroadcastingThread`; no deletion of the thread object
  is arranged when it finishes. Deleting its response does not delete the thread.
- Client 2 loss record **12,253** in `results/memcheck_client2.txt` reports
  **1,218 bytes (40 direct, 1,178 indirect)** allocated in
  `JoinGameResponseHandler::handleResponse` (`src/game/client/handlers.cpp:69`).
  `QMessageBox::information(new QWidget(), ...)` creates a parent widget whose
  ownership is never released. Closing the message box does not delete its
  parent. This is direct runtime evidence for a project-owned GUI leak despite
  the Qt frames further down the stack.

These are attributable examples, not a classification of every allocation in
the totals. They demonstrate that fixing only test cleanup would leave real
application leaks. Conversely, the two test-owned allocations described above
cannot occur through those test call sites in these standalone executables.

**Other observations and limits:** The server also reports uninitialized-value
use during response serialization (`Message::prepareMessage`, `message.cpp:8`,
through `BaseParticipant::sendResponse`). This stack alone does not identify the
uninitialized field and should not be relabeled as confirmation of the original
`currentPlayerColor` finding. Client logs also include Qt/Wayland keyboard and
shutdown memory errors; their attribution needs separate investigation.

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
