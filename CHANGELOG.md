# Changelog

## Unreleased
- Added agent contract and evidence-based task/result tracking.
- Corrected MQL5 include paths and compile/API issues.
- Verified EA and calendar exporter compile with 0 errors and 0 warnings.
## 2026-10-07
- Fixed recovery accounting: stop-loss losses are now accumulated and take-profit gains pay down unrecovered cycle loss.
- Added validation for breakout, touch/overshoot, and fixed cycle-profit inputs.
- Fixed hedging-account close-by-ticket behavior, forced-close state loop, and tester timeout measurement.
- Recompiled EA and exporter with 0 errors and 0 warnings.
- Completed baseline, 25-pass optimization, IS/OOS validation, and all-ticks OOS stress validation.
- Completed stage-2 81-pass recovery/re-entry optimization and final all-ticks OOS validation.
