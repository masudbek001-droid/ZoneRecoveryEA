# TASKS.md — ZoneRecoveryEA Task Tracker

## Task Status Legend

| Status | Meaning |
|--------|---------|
| **PENDING** | Not yet started |
| **IN PROGRESS** | Currently being worked on |
| **DONE** | Completed (see RESULTS.md for evidence) |
| **BLOCKED** | Cannot proceed — see blockers section |

---

## Phase 1: Code Audit & Compile Baseline

| ID | Task | Status | Notes |
|----|------|--------|-------|
| EA-VERIFY-001 | Full code audit against MQL5 API | DONE | See RESULTS.md |
| EA-VERIFY-002 | Fix compile blockers | DONE | 7 issues found and fixed |
| EA-VERIFY-003 | Verify MetaEditor compilation | BLOCKED | No MT5 terminal available in sandbox |
| EA-VERIFY-004 | Create TASKS.md and RESULTS.md | DONE | This file + RESULTS.md |

## Phase 2: Test Plan

| ID | Task | Status | Notes |
|----|------|--------|-------|
| EA-TEST-001 | Create deterministic test plan (2026-01-01 to 2026-10-07) | DONE | In RESULTS.md |
| EA-TEST-002 | Create optimization plan with OOS validation | DONE | In RESULTS.md |
| EA-TEST-003 | Run Strategy Tester (Every Tick, Real Ticks) | BLOCKED | No MT5 terminal |
| EA-TEST-004 | Export news calendar data | BLOCKED | No MT5 terminal |
| EA-TEST-005 | Collect backtest results | BLOCKED | Dependent on EA-TEST-003 |

## Phase 3: Optimization

| ID | Task | Status | Notes |
|----|------|--------|-------|
| EA-OPT-001 | Coarse optimization on in-sample period | BLOCKED | Dependent on EA-TEST-003 |
| EA-OPT-002 | Out-of-sample validation | BLOCKED | Dependent on EA-OPT-001 |
| EA-OPT-003 | Robustness / sensitivity analysis | BLOCKED | Dependent on EA-OPT-002 |

---

## Current Blockers

1. **No MetaTrader 5 terminal** — This sandbox environment does not have MT5 installed. All compilation and testing tasks require a Windows machine with MetaTrader 5.

2. **No tick data** — Strategy Tester real-tick backtesting requires historical tick data from a broker, which is not available in this environment.

3. **No calendar API** — NewsCalendarExporter requires a live MT5 terminal connected to a broker server.

## Next Recommended Task

**EA-VERIFY-003**: Compile in MetaEditor on a Windows machine with MT5. After fixing the issues identified in this audit, copy the MQL5/ folder to:
```
<MT5 Data Folder>\MQL5\Experts\ZoneRecoveryEA.mq5
<MT5 Data Folder>\MQL5\Include\*.mqh
<MT5 Data Folder>\MQL5\Scripts\NewsCalendarExporter.mq5
```
Open ZoneRecoveryEA.mq5 in MetaEditor, press F7, and record any remaining errors.
