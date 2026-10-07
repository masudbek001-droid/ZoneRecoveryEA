# ZoneRecoveryEA Agent Contract

This is an MQL5 Expert Advisor project. Work only on the active task in TASKS.md.

## Required workflow
- Read AGENTS.md, TASKS.md and RESULTS.md before editing.
- Never use live trading, broker credentials or secrets.
- Do not claim compilation or testing without an actual command result or tester artifact.
- Preserve the strategy specification; document any changed assumption.
- After each task, update RESULTS.md and CHANGELOG.md, inspect the diff, and create one Git commit.
- Stop on compile errors, missing MT5 data, invalid tester reports, or risk-limit violations.

## Acceptance evidence
Every test report must include symbol, timeframe, model, date range, broker/server-time assumption, spread, commission, slippage, deposit, leverage, account type, report path, and commit hash.

## Trading safety
Historical testing and demo-safe validation only. No live account actions. Never optimize only for net profit; reject configurations violating max lot, cycle loss, daily loss, cycle trades, drawdown, margin, or recovery-depth limits.
