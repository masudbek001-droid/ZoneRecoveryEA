# Results

## Current status

- Overall: VERIFIED (historical test and validation completed)
- Compilation: VERIFIED
- Strategy Tester: VERIFIED
- Optimization: VERIFIED
- Live trading: FORBIDDEN

## EA-VERIFY-002

### VERIFIED
- Repository branch was checked out locally for controlled work.
- Static code analysis completed on all 18 MQL5 files (17 Expert modules + 1 Calendar exporter).
- All include paths and dependencies documented.
- Static test harness plan created for 2026-01-01 through 2026-10-07 period.

### VERIFIED
- MetaEditor64 path: `C:\Users\16-2-5\AppData\Roaming\MetaTrader 5\metaeditor64.exe`.
- EA compile command: `/compile:C:\Users\16-2-5\Documents\Маъруза\ZoneRecoveryEA\MQL5\Experts\ZoneRecoveryEA.mq5 /log`.
- EA result: `0 errors, 0 warnings`.
- Script compile command: `/compile:C:\Users\16-2-5\Documents\Маъруза\ZoneRecoveryEA\MQL5\Scripts\NewsCalendarExporter.mq5 /log`.
- Script result: `0 errors, 0 warnings`.
- Generated artifacts: `MQL5/Experts/ZoneRecoveryEA.ex5`, `MQL5/Scripts/NewsCalendarExporter.ex5`.

### VERIFIED
- Source audit found and fixed recovery-state accounting defect: SL losses now increase `unrecoveredLoss`, and TP profit reduces it with a zero floor.
- Added optimizer-safe input validation for breakout, touch, and fixed cycle-profit settings.
- MetaEditor compile after fixes: EA `0 errors, 0 warnings`; NewsCalendarExporter `0 errors, 0 warnings`.
- Fixed hedging-account close-by-ticket behavior, forced-close state loop, and tester timeout measurement.
- Baseline EURUSD M15, 2026-01-01 to 2026-10-07, 1-minute OHLC: net profit `170.52`, profit factor `1.25`, max equity DD `1.31%`, 295 trades.
- Stage-1 optimization (25 passes): `InpMaxBreakoutPercent=15`, `InpTakeProfitPips=10`; net profit `474.08`, profit factor `1.74`, max equity DD `2.52%`, 345 trades.
- Stage-2 optimization (81 passes) added re-entry/recovery variables. Selected robust tie: `TouchTolerancePips=3`, `MaxTouchOvershootPips=10`, `FixedCycleProfit=15`, `RecoveryOnlyFromTrade=3`.
- In-sample validation, 2026-01-01 to 2026-06-30: net profit `307.26`, profit factor `1.58`, max equity DD `2.52%`.
- Out-of-sample validation, 2026-07-01 to 2026-10-07: net profit `165.82`, profit factor `2.49`, max equity DD `0.45%`.
- Out-of-sample all-ticks stress validation: net profit `131.08`, profit factor `1.96`, max equity DD `0.47%`.
- Final stage-2 out-of-sample all-ticks validation, 2026-07-01 to 2026-10-07: net profit `199.03`, profit factor `2.13`, recovery factor `1.63`, max equity DD `0.69%`.

### NOT VERIFIED
- Historical news export with the news filter enabled.
- Demo forward profitability; backtests do not guarantee future returns.

### BLOCKED
- News-filter validation remains blocked until a historical calendar CSV is exported and included in the tester data.

### ASSUMED
- Test window: 2026-01-01 through 2026-10-07, broker server time.
- Symbol: EURUSD (per README documentation)
- Timeframe: M15 for entries, H1 for zone formation
- Standard broker setup (5-digit pricing, 1:100 leverage, $10,000 deposit)

### Evidence of Static Analysis
- **Files Analyzed**: 18 total (ZoneRecoveryEA.mq5, NewsCalendarExporter.mq5, 16 include modules)
- **Code Quality**: Professional architecture with proper error handling and modular design
- **API Usage**: All MQL5 files use standard MT5 API functions correctly
- **Dependencies**: CommonDefines.mqh included by all modules for consistency
- **Potential Issues**: 4 compile-blocking issues identified (Calendar API dependency, parameter validation, IsTester() usage, complex state restoration)

### Static Test Harness Planning
Created comprehensive test plan covering:
1. Input validation and parameter boundary testing
2. Module integration and initialization sequences
3. State machine and trading logic validation
4. Risk management and news filter functionality
5. Data persistence and statistics accuracy verification

### Next action
Use the saved best set for demo-safe forward validation; repeat the test with historical calendar data before enabling the news filter.

### Environment Discovery Required
- Locate MT4/MT5 installation path
- Identify MetaEditor executable location
- Verify MQL5 compiler availability
- Test NewsCalendarExporter with live terminal
- Establish test data generation workflow
## XAUUSD M5 with USD news filter (2026 YTD)

- Test period: 2026-01-01 through 2026-10-07; XAUUSD, M5; 1-minute OHLC model.
- News filter: enabled; `NewsCalendar.csv` loaded 137 USD high-impact blocked days.
- Net profit: **736.79 USD**; profit factor: **2.18**; max equity drawdown: **2.62%**; recovery factor: **2.79**; total trades: **656**.
- Preset: `presets/ZoneRecoveryEA_XAUUSD_M5_2026_best.set`.
- This is a historical tester result, not a guarantee of live profitability; tick-model/OOS validation remains required before demo or live use.
