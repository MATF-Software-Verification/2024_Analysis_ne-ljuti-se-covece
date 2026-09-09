# Project Analysis Report

## Unit testing and code coverage

### Tool/technique

The analyzed project contains an existing Catch2 test suite. The tests were executed and code coverage was measured using LCOV.

### Procedure

The project was configured and built in Debug mode with GCC coverage instrumentation enabled using the `--coverage` compiler flag.

After the build completed, the existing Catch2 test executable was run. LCOV was then used to collect coverage data. System headers, generated build files and test source files were excluded from the final coverage report.

The analysis can be reproduced using the following script:

```bash
cd unit_tests
./run_tests.sh
```

### Running the analysis

![Running the test and coverage script](unit_tests/pictures/run_tests.png)

### Test results

All existing tests passed successfully:

- 15 test cases
- 303 assertions
- 0 failed tests

![All tests passed](unit_tests/pictures/tests_passed.png)

### Code coverage results

The resulting code coverage was:

- Line coverage: 73.2% (868/1185)
- Function coverage: 80.6% (179/222)
- Branch coverage: not collected

![LCOV coverage summary](unit_tests/pictures/coverage_summary.png)

### Conclusion

The existing test suite provides good function coverage and moderate line coverage. Approximately 27% of the source lines are not executed by the current test suite, which indicates that additional edge cases and less frequently executed code paths could be covered by further testing.
