# ZoneRecoveryEA — Professional Zone Recovery Expert Advisor

## MetaTrader 5 | Algorithmic Trading System

**Version:** 1.0.0  
**Platform:** MetaTrader 5 (MQL5)  
**Strategy:** Daily Zone Breakout with Recovery System

---

## 📋 Overview

ZoneRecoveryEA is a professional Expert Advisor for MetaTrader 5 that implements a zone-based breakout strategy with an integrated recovery system. The EA identifies a daily price zone from a specific candle, trades breakouts when price crosses zone boundaries, and uses dynamic lot sizing to recover losses through automated reversal trading.

### Key Features

- **Zone-based breakout strategy** with configurable timeframe and candle selection
- **Recovery system** with dynamic lot sizing to cover accumulated losses
- **News filter** that blocks trading on high-impact economic news days
- **Virtual stop loss** based on candle close (not just wick) beyond zone boundary
- **Re-entry system** for new cycles after TP is hit
- **Risk management** with multiple safety layers
- **State persistence** for recovery after terminal restart
- **Professional statistics** tracking and export

---

## 📁 Project Structure

```
ZoneRecoveryEA/
├── MQL5/
│   ├── Experts/
│   │   └── ZoneRecoveryEA.mq5          # Main Expert Advisor
│   ├── Include/
│   │   ├── CommonDefines.mqh           # Constants, enums, helper functions
│   │   ├── ZoneManager.mqh             # Zone identification & formation
│   │   ├── SignalEngine.mqh            # Breakout & re-entry signals
│   │   ├── TradeManager.mqh            # Order execution (CTrade wrapper)
│   │   ├── StopLossManager.mqh         # Virtual SL (candle close based)
│   │   ├── RecoveryManager.mqh         # Dynamic lot calculation
│   │   ├── ReentryManager.mqh          # Post-TP re-entry management
│   │   ├── PositionLockManager.mqh     # Single position enforcement
│   │   ├── DailySessionManager.mqh     # Daily session & forced close
│   │   ├── NewsFilter.mqh              # News filter (CSV + online)
│   │   ├── RiskManager.mqh             # Risk limits & safety
│   │   ├── StateManager.mqh            # State persistence & logging
│   │   ├── VisualManager.mqh           # Chart visualization
│   │   └── StatisticsManager.mqh       # Statistics collection
│   └── Scripts/
│       └── NewsCalendarExporter.mq5    # Historical news data exporter
├── NewsBacktestLauncher.py             # Automated backtest launcher
└── README.md                           # This file
```

---

## 🏗️ Architecture

### Modular Design

The EA uses a modular architecture with 14 independent modules:

| Module | Responsibility |
|--------|---------------|
| **ZoneRecoveryEA.mq5** | Main controller, state machine orchestration |
| **ZoneManager** | Zone candle identification, boundary calculation |
| **SignalEngine** | Breakout detection, distance filtering, re-entry |
| **TradeManager** | Order execution via CTrade, position monitoring |
| **StopLossManager** | Virtual SL based on candle body close |
| **RecoveryManager** | Dynamic lot calculation using OrderCalcProfit |
| **ReentryManager** | Post-TP touch detection for new cycles |
| **PositionLockManager** | Single position enforcement, GV synchronization |
| **DailySessionManager** | Trading window management, forced close timing |
| **NewsFilter** | High-impact news blocking (CSV + Calendar API) |
| **RiskManager** | Multi-layer risk limits, emergency stop |
| **StateManager** | Binary state save/restore, CSV trade logging |
| **VisualManager** | Chart zone display, info panel |
| **StatisticsManager** | Performance metrics, drawdown tracking |

### State Machine

```
                    ┌─────────────┐
                    │ WAIT_ZONE   │ ←── New day / Initialize
                    └──────┬──────┘
                           │ Zone formed
                    ┌──────▼──────────────┐
                    │ WAIT_INITIAL_BREAKOUT│
                    └──────┬──────────────┘
                           │ Breakout signal
                    ┌──────▼──────┐
              ┌────►│ IN_POSITION │◄────┐
              │     └──────┬──────┘     │
              │            │            │
         ┌────┴────┐  ┌───▼────┐  ┌────┴──────┐
         │ WAIT_   │  │ SL_    │  │ RISK_     │
         │ REENTRY │  │ CLOSE  │  │ HALT      │
         └────┬────┘  │ PENDING│  └───────────┘
              │       └───┬────┘
         Touch│           │ Close confirmed
              │       ┌───▼────────┐
              │       │ REVERSAL   │
              │       │ PENDING    │
              │       └───┬────────┘
              │           │ Open reversal
              └───────────┘
```

---

## ⚙️ Input Parameters

### Zone Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ZoneTimeframe` | ENUM_TIMEFRAMES | H1 | Timeframe for zone candle identification |
| `ZoneHour` | int | 9 | Hour (broker time) when zone candle opens |
| `ZoneMinute` | int | 0 | Minute when zone candle opens |

### Entry Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EntryTimeframe` | ENUM_TIMEFRAMES | M15 | Timeframe for breakout candle detection |
| `BreakoutMode` | ENUM | PERCENT | Breakout distance filter mode |
| `MaxBreakoutPercent` | double | 20.0 | Max breakout distance as % of zone size |
| `MaxBreakoutPips` | double | 5.0 | Max breakout distance in pips (if FIXED) |

### Stop Loss & Take Profit

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SLTimeframe` | ENUM_TIMEFRAMES | H1 | Timeframe for SL candle monitoring |
| `TakeProfitPips` | double | 20.0 | TP distance in pips from entry |

### Recovery Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InitialLot` | double | 0.01 | First trade lot size |
| `CycleProfitMode` | ENUM | FIXED | Profit mode (FIXED or RECOVERY_ONLY) |
| `FixedCycleProfit` | double | 10.0 | Target profit per cycle ($) |
| `RecoveryOnlyFromTrade` | int | 4 | From which trade number, profit target = 0 |

### Daily Session

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `CloseHour` | int | 23 | Daily close hour (broker time) |
| `CloseMinute` | int | 0 | Daily close minute |

### News Filter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `NewsFilterEnabled` | bool | true | Enable news filter |
| `NewsCurrencies` | string | "" | Override currencies (empty = auto) |

### Risk Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `MaxAllowedLot` | double | 1.0 | Maximum lot size |
| `MaxCycleTrades` | int | 10 | Maximum trades per cycle |
| `MaxCycleLossMoney` | double | 500.0 | Maximum loss per cycle ($) |
| `MaxDailyLossMoney` | double | 1000.0 | Maximum daily loss ($) |
| `MaxEquityDrawdownPercent` | double | 20.0 | Maximum equity drawdown (%) |
| `MaxMarginUsagePercent` | double | 50.0 | Maximum margin usage (%) |
| `MaxSpreadPips` | double | 5.0 | Maximum spread for entry (pips) |
| `MaxSlippagePoints` | double | 30.0 | Maximum slippage (points) |
| `EmergencyStopEnabled` | bool | true | Enable emergency stop |
| `EmergencyStopPips` | double | 50.0 | Emergency stop level (pips) |

---

## 📊 Strategy Logic

### Zone Formation

1. At the specified `ZoneHour:ZoneMinute`, the EA identifies the candle on `ZoneTimeframe` that opens at that time
2. After the candle closes:
   - `ZoneHigh = Candle.High` (full candle including wicks)
   - `ZoneLow = Candle.Low`
   - `ZoneSize = ZoneHigh - ZoneLow`
3. Zone is displayed on chart with horizontal lines and a colored rectangle

### Initial Breakout (First Trade)

**BUY Signal:**
- Candle Open ≤ ZoneHigh
- Candle Close > ZoneHigh (body crosses above)
- Breakout distance filter passes

**SELL Signal:**
- Candle Open ≥ ZoneLow
- Candle Close < ZoneLow (body crosses below)
- Breakout distance filter passes

Only candle BODY breakouts count — wick-only breakouts are ignored.

### Stop Loss (Virtual)

**BUY SL:** A candle on `SLTimeframe` closes with its body below `ZoneLow`
**SELL SL:** A candle on `SLTimeframe` closes with its body above `ZoneHigh`

SL is virtual — monitored by the EA, not placed on the broker.

### Take Profit

TP is placed on the broker server at:
- BUY: `EntryPrice + TakeProfitPips × PipSize`
- SELL: `EntryPrice - TakeProfitPips × PipSize`

### Recovery System

After SL, the EA opens a reversal trade with a dynamically calculated lot:

```
E(V) ≥ L + P

Where:
  V = new trade lot
  E(V) = expected profit at TP for lot V
  L = accumulated unrecovered loss
  P = profit target (0 in recovery-only mode)
```

Uses `OrderCalcProfit()` for accurate profit calculation including broker-specific contract size and tick value.

### Recovery-Only Mode

When `RecoveryOnlyFromTrade = N`:
- Trades 1 to N-1: Full recovery + profit target
- Trades N and beyond: Recovery only (P = 0)

### Re-Entry After TP

After TP is hit:
1. EA enters re-entry mode
2. Monitors both zone boundaries simultaneously:
   - Price above zone, touches ZoneHigh → BUY
   - Price below zone, touches ZoneLow → SELL
3. New cycle starts with `InitialLot`

### Daily Session End

At `CloseHour:CloseMinute`:
- All open positions are force-closed regardless of PnL
- Trading signals are suspended
- Recovery cycle is terminated
- Statistics are logged

### News Filter

- Checks MT5 Economic Calendar for high-impact (3-star) events
- If any high-impact event is found for related currencies → entire day is blocked
- On blocked days: no new trades, existing positions are force-closed
- Works offline using pre-exported CSV data for backtesting

---

## 📰 News Calendar Export

### For Live Trading

The EA automatically uses MT5's built-in Calendar API when connected to the internet.

### For Backtesting (Strategy Tester)

Since Strategy Tester doesn't support Calendar API:

1. **Run NewsCalendarExporter on live terminal:**
   ```
   Open MT5 → Scripts → NewsCalendarExporter
   Set parameters:
     - Start Date: test period start
     - End Date: test period end
     - Currencies: related currencies for your symbol
     - High Impact Only: Yes
   ```

2. **Run the Python launcher:**
   ```bash
   python NewsBacktestLauncher.py \
     --symbol EURUSD \
     --from 2024.01.01 \
     --to 2025.12.31
   ```

3. **Or manually configure Strategy Tester:**
   - Expert: ZoneRecoveryEA
   - Symbol: Your symbol
   - Period: Date range
   - Modeling: Every tick based on real ticks
   - Input: NewsFilterEnabled = true

---

## 🔒 Risk Management Layers

The EA implements multiple layers of protection:

1. **Max Lot Check** — Prevents lot exceeding `MaxAllowedLot`
2. **Margin Check** — Verifies sufficient free margin via `OrderCalcMargin()`
3. **Cycle Loss Limit** — Stops recovery if cycle loss exceeds `MaxCycleLossMoney`
4. **Daily Loss Limit** — Halts trading if daily loss exceeds `MaxDailyLossMoney`
5. **Equity Drawdown** — Activates `RISK_HALT` if drawdown exceeds threshold
6. **Margin Usage** — Prevents trading if margin usage is too high
7. **Spread Filter** — Rejects orders when spread exceeds `MaxSpreadPips`
8. **Emergency Stop** — Force closes if unrealized PnL exceeds `EmergencyStopPips`
9. **News Block** — Prevents trading on high-impact news days
10. **Day End Close** — Force closes all positions at session end

### Priority Order

```
1. News day forced close (highest)
2. Daily session end forced close
3. Emergency stop & risk limits
4. Position management (TP/SL)
5. Recovery logic
6. New signal processing (lowest)
```

---

## 📈 Info Panel

The EA displays a comprehensive information panel on the chart:

```
=== ZONE ===
Zone High: 1.08500
Zone Low:  1.08200
Zone Size: 30.0 pips
Zone TF:   PERIOD_H1
Status:    ACTIVE

=== CURRENT TRADE ===
Direction: BUY
Lot:       0.02
Entry:     1.08520
TP:        1.08720
PnL:       +12.50

=== RECOVERY ===
Cycle:     1
Trade #:   2
Loss:      15.00
Target:    25.00
Req. Lot:  0.02

=== DAILY SESSION ===
Time:      2026.10.07 14:35:22
Remaining: 08:24:38
Status:    ACTIVE

=== NEWS FILTER ===
Currencies: EUR,USD
Today:      CLEAR
Calendar:   OK

=== STATISTICS ===
Trades:    5
Cycles:    3
TP Cycles: 2
Net Profit: +35.00
```

---

## 🧪 Testing

### Compilation

1. Open MetaEditor
2. Open `ZoneRecoveryEA.mq5`
3. Press F7 to compile
4. Verify: 0 errors, 0 warnings

### Strategy Tester Configuration

- **Symbol:** EURUSD (or your target)
- **Period:** M15 or your entry timeframe
- **Date Range:** Your test period
- **Modeling:** Every tick based on real ticks
- **Deposits:** Your test deposit
- **Leverage:** Your account leverage

### Key Metrics to Track

| Metric | Description |
|--------|-------------|
| Net Profit | Total profit after all trades |
| Profit Factor | Gross profit / Gross loss |
| Max Equity Drawdown | Maximum equity drawdown % |
| Max Balance Drawdown | Maximum balance drawdown % |
| Max Consecutive Losses | Longest losing streak |
| Max Lot Used | Largest lot in recovery |
| Avg Trades per Cycle | Average trades per cycle |
| Unrecovered Loss | Loss not recovered by day end |
| Day-End Forced Closes | Number of forced day-end closes |
| News-Blocked Days | Days skipped due to news |

---

## 🔄 State Persistence

The EA saves its state to a binary file (`ZoneRecoveryEA_State.bin`) every tick. On restart:

1. State is loaded from file
2. Checksum is verified for data integrity
3. Symbol and magic number are validated
4. Position existence is verified against broker
5. If position is gone, state is adjusted accordingly
6. Trading resumes from the restored state

### Saved Data

- Zone boundaries and ID
- Current cycle data (trade number, lot, PnL, unrecovered loss)
- Current state machine state
- Last processed signal
- Position identifier

### Trade & Cycle Logging

- `ZoneRecoveryEA_Trades.csv` — Every trade with entry, exit, PnL, reason
- `ZoneRecoveryEA_Cycles.csv` — Every cycle with summary

---

## ⚠️ Important Notes

1. **Single Position Rule:** The EA enforces a single active position at all times via `PositionLockManager` with Global Variable synchronization for multi-chart scenarios.

2. **No Loss Carryover:** Each new day starts fresh with `InitialLot` and zero unrecovered loss. Previous day's unrecovered losses are NOT carried over.

3. **Netting Accounts:** On netting accounts, if other EAs/strategies trade the same symbol, positions may merge. The EA warns about this configuration.

4. **Calendar Data Revision:** Historical calendar data may be revised by providers after export. The checksum in the manifest file locks the export version.

5. **Broker Time:** All times (zone candle, close time, etc.) are in broker server time.

6. **Pip Calculation:** Pip size is automatically calculated based on symbol digits (5-digit vs 4-digit vs JPY pairs vs metals).

---

## 📝 Change Log

### v1.0.0 (2026-10-07)
- Initial release
- 14-module architecture
- Zone breakout + recovery strategy
- News filter with CSV export
- Full risk management suite
- State persistence
- Chart visualization

---

## 📄 License

This software is provided as-is for educational and trading purposes.

---

## 🔗 Support

For issues, questions, or contributions, please refer to the project repository.

---

## 📂 Deployment & Folder Structure

### Required Placement in MT5

Copy files to your MT5 Data Folder (open via File → Open Data Folder):

```
<MT5 Data Folder>\
└── MQL5\
    ├── Experts\
    │   └── ZoneRecoveryEA.mq5
    ├── Include\
    │   ├── CommonDefines.mqh
    │   ├── DailySessionManager.mqh
    │   ├── NewsFilter.mqh
    │   ├── PositionLockManager.mqh
    │   ├── RecoveryManager.mqh
    │   ├── ReentryManager.mqh
    │   ├── RiskManager.mqh
    │   ├── SignalEngine.mqh
    │   ├── StateManager.mqh
    │   ├── StatisticsManager.mqh
    │   ├── StopLossManager.mqh
    │   ├── TradeManager.mqh
    │   ├── VisualManager.mqh
    │   └── ZoneManager.mqh
    └── Scripts\
        └── NewsCalendarExporter.mq5
```

### Compilation Steps

1. Open MetaEditor (F4 from MT5 terminal)
2. Navigate to `MQL5\Experts\ZoneRecoveryEA.mq5`
3. Press **F7** (Compile)
4. Check the Errors tab — must show **0 errors**
5. The compiled `ZoneRecoveryEA.ex5` will appear in the same folder

### News Calendar Export (for backtesting)

1. In MT5 terminal, open Navigator (Ctrl+N)
2. Scripts → `NewsCalendarExporter`
3. Drag onto any chart
4. Configure parameters and run
5. Output: `NewsCalendar.csv` and `NewsCalendar_manifest.txt` in `MQL5\Files\`

### ⚠️ Compilation & Test Status

**IMPORTANT:** As of this version, the code has undergone static analysis against MQL5 API documentation but has **NOT been compiled or tested** in MetaEditor. See `RESULTS.md` and `TASKS.md` for detailed audit results and blockers.

7 compile-blocking issues were identified and fixed during audit. Remaining issues can only be discovered through actual compilation.
