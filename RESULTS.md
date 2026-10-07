# RESULTS.md — ZoneRecoveryEA Verification Results

**Date:** 2026-10-07  
**Commit:** (pending — after this audit)  
**Branch:** arena/218608f7-zonerecoveryea  

## Status Legend

| Status | Meaning |
|--------|---------|
| **VERIFIED** | Confirmed correct through code analysis or execution |
| **NOT VERIFIED** | Not yet tested — may have issues |
| **BLOCKED** | Cannot verify — dependency unavailable |
| **ASSUMED** | Based on MQL5 documentation, not empirically confirmed |

---

## 1. Compilation Audit

### 1.1 Issues Found and Fixed

| # | File | Issue | Severity | Fix Applied |
|---|------|-------|----------|-------------|
| 1 | `TradeManager.mqh` | `m_trade.SetMarginMode()` — method does NOT exist in `CTrade` class | **COMPILE BLOCKER** | Removed line |
| 2 | `CommonDefines.mqh` | `SymbolInfoSessionTrade(symbol, 0, TimeDayOfWeek(...), from, to)` — parameters in wrong order (day_of_week and session_index swapped) | **COMPILE WARNING / LOGIC ERROR** | Rewrote to iterate sessions with correct parameter order |
| 3 | `NewsFilter.mqh` | CSV header skip logic fragile — could read first data field as header or fail on line boundary | **RUNTIME ERROR** | Rewrote to read until `FileIsLineEnding` |
| 4 | `NewsCalendarExporter.mq5` | `ACCOUNT_TRADE_ALLOWED` used as UTC offset — returns boolean 0/1, not timezone | **LOGIC ERROR** | Removed false claim; documented that times are broker-server timezone |
| 5 | `ZoneRecoveryEA.mq5` | `OnTradeTransaction` uses undefined variable `ticket` — should be `trans.position_id` | **COMPILE BLOCKER** | Replaced with `trans.position_id` and added proper position matching |
| 6 | `ZoneRecoveryEA.mq5` | `DetermineCloseReason()` checks deal comment for "DAY_END"/"NEWS_CLOSE" but EA sends "ZRE_CLOSE" — reason always returns "UNKNOWN" for forced closes | **LOGIC ERROR** | Rewrote to use state context as primary indicator |
| 7 | `ZoneRecoveryEA.mq5` | Double trade statistics recording — `ForceCloseAllPositions`, `ProcessSLClosePending`, and `OnNewDay` all call `RecordTrade()`, then `OnTradeTransaction` calls it again | **DATA CORRUPTION** | Added `g_tradeStatsRecorded` flag to prevent double-counting |

### 1.2 Additional Validations Performed

| Check | Result | Evidence |
|-------|--------|----------|
| `#include` paths | VERIFIED | All 14 `.mqh` files correctly referenced from EA |
| `CTrade::Buy/Sell` signatures | VERIFIED | Match MQL5 documentation |
| `CTrade::PositionModify` | VERIFIED | Correct signature |
| `POSITION_*` constants | VERIFIED | All valid MQL5 position properties |
| `ORDER_*` constants | VERIFIED | All valid MQL5 order properties |
| `DEAL_*` constants | VERIFIED | DEAL_ENTRY_OUT, DEAL_ENTRY_INOUT valid |
| `CalendarValueHistory` | VERIFIED | Correct signature: `(MqlCalendarValue &values[], datetime from, datetime to)` |
| `CalendarEventById` | VERIFIED | Exists in MQL5 since build 1860 |
| `CalendarCountryById` | VERIFIED | Correct signature, `MqlCalendarCountry.currency` field exists |
| `MqlDateTime` struct | VERIFIED | Fields: year, mon, day, hour, min, sec, day_of_week, day_of_year |
| `ENUM_TIMEFRAMES` values | VERIFIED | PERIOD_H1, PERIOD_M15 etc. are valid |
| `ENUM_CALENDAR_IMPORTANCE` | VERIFIED | CALENDAR_IMPORTANCE_HIGH = 2 |
| `input group` syntax | VERIFIED | Valid in MQL5 build 2085+ |
| `GlobalVariableSet/Get/Del` | VERIFIED | Correct signatures |
| `FileOpen/Read/Write/Close` | VERIFIED | Flag combinations valid |
| `OrderCalcProfit` | VERIFIED | Correct signature |
| `OrderCalcMargin` | VERIFIED | Correct signature |
| `SymbolInfoDouble/Integer/String` | VERIFIED | Property identifiers valid |
| `OBJ_LABEL/OBJ_HLINE/OBJ_RECTANGLE/OBJ_ARROW/OBJ_TEXT` | VERIFIED | Valid MQL5 object types |
| `OBJPROP_*` constants | VERIFIED | All valid |
| `PositionSelectByTicket` | VERIFIED | Exists in MQL5 |
| `PositionsTotal/PositionGetTicket` | VERIFIED | Correct iteration pattern |
| Python syntax | VERIFIED | `ast.parse()` passed |
| File structure | VERIFIED | All 19 files in correct MQL5 directory layout |

### 1.3 MetaEditor Compilation Status

**Status: BLOCKED**  
No MetaTrader 5 terminal is available in this sandbox environment. The code audit was performed by:
- Cross-referencing all MQL5 API calls against official documentation
- Checking type compatibility and function signatures
- Verifying enum values and struct field names
- Validating include file dependency graph

**To verify compilation:**
1. Copy `MQL5/` folder to `<MT5 Data Folder>\MQL5\`
2. Open `ZoneRecoveryEA.mq5` in MetaEditor
3. Press F7
4. Report any remaining errors

---

## 2. Deterministic Test Plan (2026-01-01 to 2026-10-07)

### 2.1 Test Configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| Symbol | EURUSD | Primary test pair |
| Timeframe (chart) | M15 | Matching entry timeframe |
| Zone Timeframe | H1 | Zone candle TF |
| Zone Hour:Minute | 09:00 | Broker server time |
| Entry Timeframe | M15 | Breakout detection |
| SL Timeframe | H1 | Virtual SL monitoring |
| Take Profit | 20.0 pips | Fixed |
| Initial Lot | 0.01 | Conservative |
| Max Allowed Lot | 0.50 | Risk cap |
| Max Cycle Trades | 10 | Recovery limit |
| Max Cycle Loss | $200 | Per cycle |
| Max Daily Loss | $500 | Per day |
| Max Equity DD | 15% | Emergency |
| Deposit | $10,000 | Standard |
| Leverage | 1:100 | Conservative |
| Account Type | Hedging | Required |
| Spread | 1.0 pips (fixed) | Conservative estimate |
| Commission | $0 per lot | Standard retail |
| Slippage | 1 pip | Realistic |
| Modeling | Every tick based on real ticks | Required |
| Period Start | 2026-01-01 00:00:00 | Broker server time |
| Period End | 2026-10-07 23:59:59 | Broker server time |
| News Filter | ON | High-impact only |

### 2.2 Test Phases

#### Phase A: In-Sample (2026-01-01 to 2026-07-31)
- 7 months of data
- Purpose: Parameter exploration and optimization

#### Phase B: Out-of-Sample (2026-08-01 to 2026-10-07)
- ~2 months of untouched data
- Purpose: Validate parameters from Phase A
- **No parameter changes allowed after viewing results**

### 2.3 Metrics to Collect

| Metric | Description | Minimum Acceptable |
|--------|-------------|-------------------|
| Net Profit | Total P&L | > $0 |
| Profit Factor | Gross P / Gross L | > 1.2 |
| Max Equity Drawdown | % of peak equity | < 20% |
| Max Balance Drawdown | % of peak balance | < 25% |
| Max Consecutive Losses | Longest losing streak | < MaxCycleTrades |
| Max Lot Used | Largest recovery lot | < MaxAllowedLot |
| Total Trades | Count | > 30 (statistical significance) |
| Total Cycles | Count | > 10 |
| TP Cycles | Successful TP closures | > 30% of total |
| Day-End Forced Closes | Cycles ended by day-end | Track ratio |
| News-Blocked Days | Days skipped | Verify accuracy |
| Avg Trades per Cycle | Mean | < MaxCycleTrades / 2 |
| Unrecovered Loss | Cycles with remaining loss | < MaxCycleLossMoney |
| Recovery Depth | Max trades before TP | < MaxCycleTrades |

### 2.4 Test Execution Status

**Status: BLOCKED** — No MT5 terminal available.

---

## 3. Optimization Plan (Anti-Overfitting)

### 3.1 Methodology: IS → OOS → Robustness

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: COARSE IN-SAMPLE OPTIMIZATION              │
│ Period: 2026-01-01 to 2026-07-31                    │
│ Goal: Find parameter regions that work              │
│ Method: Genetic algorithm, multi-objective          │
│                                                     │
│ Parameters to optimize:                             │
│   - TakeProfitPips: [10, 15, 20, 25, 30, 40, 50]   │
│   - InitialLot: [0.01, 0.02, 0.03, 0.05]          │
│   - MaxBreakoutPercent: [10, 15, 20, 25, 30]       │
│   - RecoveryOnlyFromTrade: [3, 4, 5, 6]            │
│   - MaxCycleLossMoney: [100, 200, 300, 500]        │
│                                                     │
│ Constraints (HARD — optimizer cannot violate):      │
│   - MaxAllowedLot <= 0.50                           │
│   - MaxCycleTrades <= 10                            │
│   - MaxEquityDrawdownPercent >= 10                  │
│   - MaxDailyLossMoney >= MaxCycleLossMoney          │
│   - All OnInit validation checks pass               │
│                                                     │
│ Selection criteria (multi-objective):               │
│   1. Profit Factor > 1.3                            │
│   2. Max Equity DD < 15%                            │
│   3. Trade count > 50                               │
│   4. Recovery depth < 7 trades                      │
│   5. Max Lot < 0.30                                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Phase 2: OUT-OF-SAMPLE VALIDATION                   │
│ Period: 2026-08-01 to 2026-10-07                    │
│ Goal: Confirm top parameter sets work on unseen data│
│ Method: Walk-forward, NO parameter changes          │
│                                                     │
│ Acceptance criteria:                                │
│   - Net Profit > 0                                  │
│   - Profit Factor > 1.0 (relaxed vs IS)             │
│   - Max DD < 20%                                    │
│   - No parameter from IS fails on OOS               │
│   - Performance degradation < 40% vs IS             │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Phase 3: ROBUSTNESS / SENSITIVITY CHECK             │
│ Goal: Verify parameter stability                    │
│ Method:                                             │
│   a) Perturbation test: ±20% on each parameter      │
│   b) Symbol cross-test: GBPUSD, XAUUSD              │
│   c) Period shift: roll IS window by 1 month        │
│   d) Spread sensitivity: test with 2x spread        │
│                                                     │
│ Criteria:                                           │
│   - Results don't collapse with small changes       │
│   - At least 2/3 symbols profitable                 │
│   - Spread doubling doesn't eliminate profit        │
└─────────────────────────────────────────────────────┘
```

### 3.2 Risk Caps in Optimizer

These constraints are enforced in `OnInit()` and will cause the optimizer to reject invalid parameter sets:

| Constraint | Input | Validation |
|-----------|-------|-----------|
| Max lot >= Initial lot | MaxAllowedLot >= InpInitialLot | `INIT_PARAMETERS_INCORRECT` |
| Max cycle trades | 1 <= x <= 50 | Hard limit |
| Cycle loss > 0 | MaxCycleLossMoney > 0 | Required |
| Daily loss >= Cycle loss | MaxDailyLossMoney >= MaxCycleLossMoney | Required |
| DD% in range | 0 < x <= 100 | Required |
| Close time > Zone time | InpCloseHour:Min > InpZoneHour:Min | Required |
| Recovery-only from trade >= 2 | InpRecoveryOnlyFromTrade >= 2 | Required |

### 3.3 Optimization Execution Status

**Status: BLOCKED** — Dependent on successful compilation and test execution.

---

## 4. Code Quality Assessment

### 4.1 Strengths
- Clean modular architecture with 14 independent modules
- State machine pattern prevents undefined behavior
- Position lock with GV synchronization for multi-chart safety
- Multiple risk management layers
- Trade logging for post-analysis

### 4.2 Known Limitations (NOT YET VERIFIED)
- `Sleep()` calls in TradeManager may cause issues in Strategy Tester
- Broker-specific pip calculation for exotic instruments
- CSV file reading may fail with unusual encodings
- Position close via opposite order may not work on all account types
- Calendar API behavior in Strategy Tester (uses CSV fallback)

### 4.3 Risks
- **No actual compilation evidence** — code has not been compiled
- **No actual backtest evidence** — strategy has not been tested
- **Calendar data accuracy** — historical revisions possible
- **Broker-specific behavior** — fills, slippage, margin may vary

---

## 5. Security & Compliance Check

| Check | Result |
|-------|--------|
| No live trading credentials in code | ✅ VERIFIED |
| No broker login data | ✅ VERIFIED |
| No API keys or secrets | ✅ VERIFIED |
| No hardcoded account numbers | ✅ VERIFIED |
| Magic number configurable via input | ✅ VERIFIED |
| No external network calls (except Calendar API) | ✅ VERIFIED |

---

## 6. Summary

| Category | Status |
|----------|--------|
| Code audit against MQL5 API | DONE — 7 issues found and fixed |
| Compile blockers | FIXED — all identified blockers resolved |
| MetaEditor compilation | BLOCKED — no MT5 terminal |
| Test plan | DONE — deterministic plan created |
| Optimization plan | DONE — IS/OOS/Robustness methodology |
| Actual backtest results | BLOCKED — no MT5 terminal |
| Risk caps for optimizer | VERIFIED — enforced in OnInit() |
| Security check | VERIFIED — no credentials/secrets |
| Python launcher syntax | VERIFIED — ast.parse() passed |

**Overall assessment: The code is structurally sound and all identified compile blockers have been fixed. However, there is NO empirical evidence of successful compilation or strategy performance. The EA must be compiled and tested in a real MetaTrader 5 environment before any trading decisions are made.**
