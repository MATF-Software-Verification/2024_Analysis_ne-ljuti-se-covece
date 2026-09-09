# Unit testing and code coverage

## Description

The analyzed project contains an existing test suite implemented using Catch2.

The purpose of this analysis is to execute the existing unit tests and measure the code coverage achieved by the test suite.

LCOV is used for coverage measurement. Coverage is collected after building the project with GCC coverage instrumentation enabled using the `--coverage` compiler flag.

## Requirements

The following tools are required:

- CMake
- GCC/G++
- Qt 6
- LCOV

LCOV can be installed on Ubuntu using:

```bash
sudo apt update
sudo apt install lcov
```

## Running the analysis

From the `unit_tests` directory run:

```bash
./run_tests.sh
```

The script performs the following steps:

1. Removes the previous coverage build directory.
2. Configures the project in Debug mode.
3. Enables GCC coverage instrumentation using the `--coverage` flag.
4. Builds the project.
5. Executes the existing Catch2 test suite.
6. Collects coverage data using LCOV.
7. Removes system headers, generated files, build files and test source files from the final coverage report.
8. Saves the filtered coverage report and summary.

## Results

The existing test suite completed successfully:

- 15 test cases
- 303 assertions
- 0 failed tests

Code coverage results:

- Line coverage: 73.2% (868/1185)
- Function coverage: 80.6% (179/222)
- Branch coverage: not collected

The generated results are stored in:

```text
results/
```

The screenshots used in the analysis report are stored in:

```text
pictures/
```

The expected directory structure is:

```text
unit_tests/
├── README.md
├── run_tests.sh
├── results/
│   ├── coverage_filtered.info
│   └── coverage_summary.txt
└── pictures/
    ├── run_tests.png
    ├── tests_passed.png
    └── coverage_summary.png
```

## Conclusion

The existing test suite provides good function coverage and moderate line coverage. Approximately 27% of the source lines remain uncovered, which indicates that additional edge cases and less frequently executed code paths could be tested.
