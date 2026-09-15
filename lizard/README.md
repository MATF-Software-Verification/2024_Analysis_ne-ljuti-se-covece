# Lizard Analysis

## Tool

Lizard is a static code complexity analysis tool for C/C++ and several other programming languages.

It was used to analyze the production source code of the project and identify functions with high structural complexity.

The analyzed directories are:

```text
src/common
src/server
src/game
```

The existing test code was not included in this analysis.

Lizard reports several metrics for each function:

- **NLOC** - number of logical lines of code,
- **CCN** - Cyclomatic Complexity Number,
- **token count** - number of lexical tokens in the function,
- **PARAM** - number of function parameters,
- **length** - total function length in lines.

The most important metric for this analysis is **CCN**, which represents the number of independent execution paths through a function.

Higher cyclomatic complexity usually indicates that a function is more difficult to understand, test and maintain.

## Version

The analysis was performed using:

```text
Lizard 1.24.0
```

## Running the analysis

From the `lizard` directory run:

```bash
./run_lizard.sh
```

The script analyzes the main production directories:

```text
../ne-ljuti-se-covece/src/common
../ne-ljuti-se-covece/src/server
../ne-ljuti-se-covece/src/game
```

The complete output is stored in:

```text
results/lizard.txt
```

## Script

The analysis is executed using:

```bash
lizard \
  "$PROJECT_DIR/src/common" \
  "$PROJECT_DIR/src/server" \
  "$PROJECT_DIR/src/game"
```

The default Lizard warning thresholds are used.

In this execution, warnings were generated for functions whose cyclomatic complexity was greater than 15.

## Results

Lizard analyzed:

```text
37 files
293 functions
3294 total NLOC
```

The average values for the analyzed code were:

```text
Avg.NLOC  = 8.4
Avg.CCN   = 1.8
Avg.token = 57.2
```

A total of:

```text
3 warnings
```

were reported.

## High-complexity functions

Lizard identified three functions whose cyclomatic complexity exceeded the default warning threshold.

### Board::isPawnMoveValid

```text
NLOC:   29
CCN:    19
Tokens: 264
Params: 3
Length: 31
```

Location:

```text
src/server/board.cpp
```

This function has the highest cyclomatic complexity reported by Lizard.

A CCN value of 19 indicates that the function contains a relatively large number of independent execution paths.

This makes the function more difficult to fully test because multiple combinations of conditions and branches must be considered.

### MessageFactory::createMessage

```text
NLOC:   77
CCN:    18
Tokens: 485
Params: 1
Length: 80
```

Location:

```text
src/common/messagefactory.cpp
```

This function parses incoming messages and selects the appropriate message type.

Its relatively high cyclomatic complexity is consistent with the large number of branches required to distinguish different message types.

This function was also selected as the target for the libFuzzer analysis because it processes external input and contains multiple execution paths.

### ActivateMagicMessageHandler::handleMessage

```text
NLOC:   44
CCN:    16
Tokens: 355
Params: 2
Length: 51
```

Location:

```text
src/server/handlers.cpp
```

The function also exceeds the default Lizard complexity threshold.

Its complexity is caused by multiple conditions related to validation and handling of the Activate Magic operation.

This function is especially interesting because other verification tools also reported problems in the same area of the project.

## Interpretation

High cyclomatic complexity does not necessarily indicate a software defect.

Instead, it indicates that the function contains a relatively large number of possible execution paths.

Such functions may:

- require more test cases,
- be more difficult to understand,
- be more difficult to maintain,
- have a higher probability of introducing defects when modified.

For this reason, functions with high CCN values are useful candidates for additional testing or refactoring.

## Conclusion

Lizard identified three functions with cyclomatic complexity greater than the default threshold of 15:

```text
Board::isPawnMoveValid                         CCN 19
MessageFactory::createMessage                  CCN 18
ActivateMagicMessageHandler::handleMessage     CCN 16
```

The highest value was found in `Board::isPawnMoveValid` with a CCN of 19.

The analysis complements the other tools used in this project because it focuses on **structural code complexity**, rather than memory errors, undefined behavior or conventional static bug detection.
