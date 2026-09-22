# Standalone gameplay analysis with AddressSanitizer

## Setup and recorded scenario

The original project applications were built in `ne-ljuti-se-covece/build-asan-game` in Debug mode with `-fsanitize=address -fno-omit-frame-pointer` and the executable linker flag `-fsanitize=address`. Only the `server` and `game` targets were requested. The applications were launched manually with `ASAN_OPTIONS=detect_leaks=1`, using one server and two clients. The client reports contain Qt 6 and Wayland frames. The controlled experiment patches were not part of this gameplay setup.

The logs record a game created for two human players, with two bots, followed by joining, readiness and game start, dice rolls, pawn moves and end-turn responses. Magic requests include `double_dice`, `shield`, `plus_1` and `remote_dice` (with value 5). A request alone does not establish successful activation. The server records both clients disconnecting. The user reported finishing the gameplay session; the logs do not establish a complete game played to victory. Exact duration and process exit statuses were not recorded.

## Results

| Process | Direct leaks (bytes/allocations) | Indirect leaks (bytes/allocations) | Total (bytes/allocations) |
| --- | ---: | ---: | ---: |
| Client 1 | 5952 / 62 | 933 / 12 | 6885 / 74 |
| Client 2 | 5568 / 58 | 1396 / 11 | 6964 / 69 |
| Server | Not available | Not available | No final LeakSanitizer report |

The direct and indirect subtotals were obtained by summing the corresponding records in each client log. Both totals agree with the final sanitizer summaries:

```text
Client 1: SUMMARY: AddressSanitizer: 6885 byte(s) leaked in 74 allocation(s).
Client 2: SUMMARY: AddressSanitizer: 6964 byte(s) leaked in 69 allocation(s).
```

No use-after-free, buffer-overflow or double-free diagnostic appears in these three logs. Both client reports reach a final leak summary. The server log contains gameplay output but no final sanitizer summary; it must not be reported as leak-free. The suggested procedure stopped the server with Ctrl+C, which does not establish normal application cleanup or a completed leak check. The log itself does not record the termination signal.

## Allocation traces and interpretation

All reported direct leak records in both clients originate from allocations in `libwayland-client`. Some stacks also pass through application GUI actions. These traces identify allocation paths, but do not alone establish whether the ultimate responsibility belongs to the platform or the application. A minimal Qt control or a backend comparison would be needed for stronger attribution.

Client 2 also contains project-specific indirect allocation traces:

- `JoinGameResponseHandler::handleResponse`, `src/game/client/handlers.cpp:69`: `QMessageBox::information(new QWidget(), ...)` allocates a parent widget without arranging its deletion. The 40-byte widget allocation is explicitly reported as an indirect leak, along with related Qt allocations. Closing the message box does not release this separately allocated parent. The same source location was identified in the standalone Valgrind analysis, although its leak classification and totals differ.
- `MainWindow::on_joinButton_clicked`, `src/game/view/mainwindow.cpp:94`: the report includes the 24-byte allocation of `new DefaultResponseHandler`, with related QObject allocations through `ClientChainElement`. The constructor uses `QObject{nextElement}`, making the next handler the QObject parent of the current handler. Destruction of the stack-allocated current handler does not delete that parent. This points to incomplete ownership of the allocated fallback handler.

Indirect records must not be presented as independent direct roots or added a second time to the summary. Library allocation frames do not exclude an application ownership defect, and aggregate totals cannot be subtracted from the earlier test or Valgrind totals to calculate production leakage.

## Conclusion

The standalone run detected memory leaks in both clients during an actual gameplay session, independently of Catch2 test cleanup. It also supplied project-specific ownership evidence in the join-game GUI and handler setup. No other ASan memory-access diagnostic was recorded for the executed paths. The server's leak status remains undetermined because its log lacks a final LeakSanitizer report. These results supplement, rather than replace, the earlier test and controlled-experiment findings.

## Raw evidence

- [Server output](game_server.txt)
- [Client 1 output and leak report](game_client.txt)
- [Client 2 output and leak report](game_client2.txt)
