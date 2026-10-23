# Integration-test golden files — Spain (ES), training-data baseline

Golden CSVs that `RunSimPathsESIntegrationTest` diffs against when
`parameter_args.trainingFlag: true` in `config/test_run_ES.yml` (the default).

These CSVs **are committed**, because the training data is shareable. This is the
CI-ready regression baseline that every PR is diffed against — the exact counterpart
of [`../expected_training_PL/`](../expected_training_PL/INTEGRATION_TEST_REGENERATION.md).

| | training data | real data |
|---|---|---|
| output folder | `output/INTEGRATION_TESTS_TRAINING_ES/` | `output/INTEGRATION_TESTS_ES/` |
| golden files | `expected_training_ES/` (committed) | [`../expected_ES/`](../expected_ES/INTEGRATION_TEST_REGENERATION.md) (gitignored) |

Inputs: `input/ES/InitialPopulations/training/` (2011–2024) and
`input/ES/EUROMODoutput/training/` (2005–2025), both committed.

This file is deliberately not called `README.md`. Every simulation run writes its own
`README.md` (the run configuration, from `OutputReadme`) beside its CSVs, and copying
a whole output folder here once overwrote these instructions.

## Regenerating the baseline

Do this only when you have **intentionally** changed model behaviour and confirmed
the new output is correct. The new CSVs are committed and become the reference every
PR is diffed against.

`config/test_run_ES.yml` sets no `model_args`, so the run uses `SimPathsModel`'s
defaults. Changing one of them moves this baseline, as switching `alignCohabitation`
to `true` did. A change to country-generic code usually moves the PL baseline as well,
so regenerate both.

```sh
mvn clean package -DskipTests
mvn verify -Dit.test=RunSimPathsESIntegrationTest

SRC=output/INTEGRATION_TESTS_TRAINING_ES/csv
DST=src/test/java/simpaths/integrationtest/expected_training_ES
cp "$SRC/WealthIncomeStatistics.csv" "$SRC/DemographicStatistics.csv" \
   "$SRC/HealthStatistics.csv" "$SRC/HealthByGender.csv" \
   "$SRC/LabourStatistics.csv" "$DST/"
git add "$DST"/*.csv

mvn verify -Dit.test=RunSimPathsESIntegrationTest   # confirm green, then commit
```

Copy only these five CSVs, not the run's `README.md`. `AlignmentStatistics.csv` is
only checked for existence, not diffed.

## When the diff fires on someone else's PR

The training-data baseline is the repo's contract: if the diff fires on a PR, the
change moved simulated output and the author needs to justify it. If the change is
intentional, regenerate and commit the baseline as above; if not, the diff is exactly
the signal that caught a regression.

## Caveat on the numbers

The ES baseline pins *reproducibility*, not correctness. Some ES inputs are not final
yet (see "Still outstanding" in the Spain section of `CLAUDE.md`), and results from
training data are for development only. The test's job is to catch unintended
movement, and to catch ES breaking outright when country-generic code changes.

## Comparison rules

Same hybrid tolerance as every other baseline — see
[`../expected_PL/INTEGRATION_TEST_REGENERATION.md`](../expected_PL/INTEGRATION_TEST_REGENERATION.md#comparison-rules).
