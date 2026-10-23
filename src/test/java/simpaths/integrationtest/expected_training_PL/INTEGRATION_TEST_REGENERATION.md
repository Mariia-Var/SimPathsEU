# Integration-test golden files — Poland (PL), training-data baseline

Golden CSVs that `RunSimPathsPLIntegrationTest` diffs against when
`parameter_args.trainingFlag: true` in `config/test_run_PL.yml` (the default).

These CSVs **are committed**, because the training data is shareable. This is the
CI-ready regression baseline that every PR is diffed against.

| | training data | real data |
|---|---|---|
| output folder | `output/INTEGRATION_TESTS_TRAINING_PL/` | `output/INTEGRATION_TESTS_PL/` |
| golden files | `expected_training_PL/` (committed) | [`../expected_PL/`](../expected_PL/INTEGRATION_TEST_REGENERATION.md) (gitignored) |

Both are derived from the country code and the training flag, so Spain follows the
identical convention under `expected_training_ES/` and `expected_ES/`.

This file is deliberately not called `README.md`. Every simulation run writes its own
`README.md` (the run configuration, from `OutputReadme`) beside its CSVs, and copying
a whole output folder here once overwrote these instructions.

## Regenerating the baseline

Do this only when you have **intentionally** changed model behaviour and confirmed
the new output is correct. The new CSVs are committed and become the reference every
PR is diffed against.

`config/test_run_PL.yml` sets no `model_args`, so the run uses `SimPathsModel`'s
defaults. Changing one of them moves this baseline, as switching `alignCohabitation`
to `true` did. A change to country-generic code usually moves the ES baseline as well,
so regenerate both.

1. Keep `parameter_args.trainingFlag: true` in `config/test_run_PL.yml`. That is the
   only place the flag lives — the test passes it on to the `-DBSetup` step as `-t`,
   so `config/test_create_database_PL.yml` does not repeat it.

2. Make sure the training input data is in place under
   `input/PL/InitialPopulations/training/` (2011–2023) and
   `input/PL/EUROMODoutput/training/` (2010–2024)
   (see `Parameters.getInputDirectoryInitialPopulations` /
   `Parameters.getEuromodOutputDirectory`, which switch on `trainingFlag`).

3. Build and run:

    ```sh
    mvn clean package -DskipTests
    mvn verify -Dit.test=RunSimPathsPLIntegrationTest
    ```

4. Copy the actual outputs as the new baseline and commit them. Copy only these five
   CSVs, not the run's `README.md`. `AlignmentStatistics.csv` is only checked for
   existence, not diffed.

    ```sh
    SRC=output/INTEGRATION_TESTS_TRAINING_PL/csv
    DST=src/test/java/simpaths/integrationtest/expected_training_PL
    cp "$SRC/WealthIncomeStatistics.csv" "$SRC/DemographicStatistics.csv" \
       "$SRC/HealthStatistics.csv" "$SRC/HealthByGender.csv" \
       "$SRC/LabourStatistics.csv" "$DST/"
    git add "$DST"/*.csv
    ```

5. Re-run `mvn verify -Dit.test=RunSimPathsPLIntegrationTest` to confirm green, then commit.

## When the diff fires on someone else's PR

The training-data baseline is the repo's contract: if the diff fires on a PR, the
change moved simulated output and the author needs to justify it. If the change is
intentional, regenerate and commit the baseline as above; if not, the diff is exactly
the signal that caught a regression.

## Comparison rules

Same hybrid tolerance as every other baseline — see
[`../expected_PL/INTEGRATION_TEST_REGENERATION.md`](../expected_PL/INTEGRATION_TEST_REGENERATION.md#comparison-rules).
