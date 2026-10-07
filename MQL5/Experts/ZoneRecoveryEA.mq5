//+------------------------------------------------------------------+
//|                                                ZoneRecoveryEA.mq5|
//|           Professional Zone Recovery Expert Advisor               |
//|           Strategy: Daily Zone Breakout + Recovery System         |
//+------------------------------------------------------------------+
#property copyright   "ZoneRecoveryEA"
#property version     "1.00"
#property description "Professional Zone Recovery EA with News Filter"
#property strict

#include "..\Include\CommonDefines.mqh"
#include "..\Include\ZoneManager.mqh"
#include "..\Include\SignalEngine.mqh"
#include "..\Include\TradeManager.mqh"
#include "..\Include\StopLossManager.mqh"
#include "..\Include\RecoveryManager.mqh"
#include "..\Include\ReentryManager.mqh"
#include "..\Include\PositionLockManager.mqh"
#include "..\Include\DailySessionManager.mqh"
#include "..\Include\NewsFilter.mqh"
#include "..\Include\RiskManager.mqh"
#include "..\Include\StateManager.mqh"
#include "..\Include\VisualManager.mqh"
#include "..\Include\StatisticsManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Zone Settings
input group "=== ZONE SETTINGS ==="
input ENUM_TIMEFRAMES  InpZoneTimeframe       = PERIOD_H1;       // Zone Timeframe
input int              InpZoneHour            = 9;               // Zone Candle Open Hour (broker time)
input int              InpZoneMinute          = 0;               // Zone Candle Open Minute

//--- Entry Settings
input group "=== ENTRY SETTINGS ==="
input ENUM_TIMEFRAMES  InpEntryTimeframe      = PERIOD_M15;      // Entry Timeframe
input ENUM_BREAKOUT_MODE InpBreakoutMode      = BREAKOUT_MODE_PERCENT; // Breakout Distance Mode
input double           InpMaxBreakoutPercent  = 20.0;            // Max Breakout Distance (% of zone)
input double           InpMaxBreakoutPips     = 5.0;             // Max Breakout Distance (pips, if FIXED)

//--- Stop Loss Settings
input group "=== STOP LOSS SETTINGS ==="
input ENUM_TIMEFRAMES  InpSLTimeframe         = PERIOD_H1;       // Stop Loss Timeframe

//--- Take Profit Settings
input group "=== TAKE PROFIT SETTINGS ==="
input double           InpTakeProfitPips      = 20.0;            // Take Profit (pips)

//--- Re-entry Settings
input group "=== RE-ENTRY SETTINGS ==="
input double           InpTouchTolerancePips   = 2.0;            // Touch Tolerance (pips)
input double           InpMaxTouchOvershootPips = 10.0;          // Max Touch Overshoot (pips)

//--- Recovery Settings
input group "=== RECOVERY SETTINGS ==="
input double           InpInitialLot          = 0.01;            // Initial Lot Size
input ENUM_CYCLE_PROFIT_MODE InpCycleProfitMode = CYCLE_PROFIT_FIXED; // Cycle Profit Mode
input double           InpFixedCycleProfit    = 10.0;            // Fixed Cycle Profit Target ($)
input int              InpRecoveryOnlyFromTrade = 4;             // Recovery-only from trade # (P=0)

//--- Daily Session Settings
input group "=== DAILY SESSION ==="
input int              InpCloseHour           = 23;              // Daily Close Hour (broker time)
input int              InpCloseMinute         = 0;               // Daily Close Minute

//--- News Filter Settings
input group "=== NEWS FILTER ==="
input bool             InpNewsFilterEnabled   = true;            // Enable News Filter
input string           InpNewsCurrencies      = "";              // News Currencies (empty=auto detect)

//--- Risk Management
input group "=== RISK MANAGEMENT ==="
input double           InpMaxAllowedLot       = 1.0;             // Maximum Allowed Lot
input int              InpMaxCycleTrades      = 10;              // Maximum Trades per Cycle
input double           InpMaxCycleLossMoney   = 500.0;           // Maximum Cycle Loss ($)
input double           InpMaxDailyLossMoney   = 1000.0;          // Maximum Daily Loss ($)
input double           InpMaxEquityDrawdownPercent = 20.0;       // Maximum Equity Drawdown (%)
input double           InpMaxMarginUsagePercent = 50.0;          // Maximum Margin Usage (%)
input double           InpMaxSpreadPips       = 5.0;             // Maximum Spread (pips)
input double           InpMaxSlippagePoints   = 30.0;            // Maximum Slippage (points)
input bool             InpEmergencyStopEnabled = true;           // Enable Emergency Stop
input double           InpEmergencyStopPips   = 50.0;            // Emergency Stop Level (pips)

//--- Display Settings
input group "=== DISPLAY ==="
input bool             InpShowInfoPanel       = true;            // Show Info Panel
input bool             InpShowZoneOnChart     = true;            // Show Zone on Chart
input bool             InpShowPreviousZones   = true;            // Show Previous Zones
input color            InpZoneColor           = clrDodgerBlue;   // Zone Color
input int              InpZoneLineThickness   = 2;               // Zone Line Thickness
input int              InpZoneFillOpacity     = 30;              // Zone Fill Opacity
input int              InpPanelX              = 10;              // Panel X Position
input int              InpPanelY              = 30;              // Panel Y Position

//--- System Settings
input group "=== SYSTEM ==="
input ulong            InpMagicNumber         = 218608;          // Magic Number
input bool             InpEnableStateSave     = true;            // Enable State Saving

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+

//--- Module instances
CZoneManager         g_zoneManager;
CSignalEngine        g_signalEngine;
CTradeManager        g_tradeManager;
CStopLossManager     g_slManager;
CRecoveryManager     g_recoveryManager;
CReentryManager      g_reentryManager;
CPositionLockManager g_posLockManager;
CDailySessionManager g_dailySession;
CNewsFilter          g_newsFilter;
CRiskManager         g_riskManager;
CStateManager        g_stateManager;
CVisualManager       g_visualManager;
CStatisticsManager   g_statsManager;

//--- EA State
ENUM_ZONE_STATE      g_currentState;
ENUM_SIGNAL_TYPE     g_lastSignal;
string               g_symbol;
bool                 g_initialized = false;
bool                 g_stateRestored = false;
datetime             g_lastTickTime = 0;
datetime             g_lastDayChecked = 0;
bool                 g_positionJustClosed = false;
ulong                g_lastTradeTransactionID = 0;

//--- Current data
ZoneData             g_currentZone;
CycleData            g_currentCycle;

//--- Prevents double-counting in OnTradeTransaction when stats already
//    recorded by ForceCloseAllPositions or ProcessSLClosePending
bool                 g_tradeStatsRecorded = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_symbol = _Symbol;
   g_currentState = STATE_WAIT_ZONE;
   g_lastSignal   = SIGNAL_NONE;
   g_positionJustClosed = false;
   g_tradeStatsRecorded = false;
   
   //--- Input validation: reject invalid configurations
   //    Returns INIT_PARAMETERS_INCORRECT to prevent optimizer from testing these
   
   if(InpZoneHour < 0 || InpZoneHour > 23 || InpZoneMinute < 0 || InpZoneMinute > 59)
   {
      Print("ERROR: Invalid ZoneHour/ZoneMinute values");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpCloseHour < 0 || InpCloseHour > 23 || InpCloseMinute < 0 || InpCloseMinute > 59)
   {
      Print("ERROR: Invalid CloseHour/CloseMinute values");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpInitialLot <= 0)
   {
      Print("ERROR: InitialLot must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxAllowedLot < InpInitialLot)
   {
      Print("ERROR: MaxAllowedLot must be >= InitialLot");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxAllowedLot > SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX))
   {
      // Clamp to broker max - don't reject, just warn
      PrintFormat("WARNING: MaxAllowedLot %.2f clamped to broker max %.2f",
                  InpMaxAllowedLot, SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX));
   }
   if(InpTakeProfitPips <= 0)
   {
      Print("ERROR: TakeProfitPips must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpBreakoutMode == BREAKOUT_MODE_PERCENT &&
      (InpMaxBreakoutPercent <= 0 || InpMaxBreakoutPercent > 100))
   {
      Print("ERROR: MaxBreakoutPercent must be > 0 and <= 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpBreakoutMode == BREAKOUT_MODE_FIXED && InpMaxBreakoutPips <= 0)
   {
      Print("ERROR: MaxBreakoutPips must be > 0 in FIXED breakout mode");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTouchTolerancePips < 0 || InpMaxTouchOvershootPips < InpTouchTolerancePips)
   {
      Print("ERROR: Touch overshoot must be >= touch tolerance and both must be non-negative");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpCycleProfitMode == CYCLE_PROFIT_FIXED && InpFixedCycleProfit <= 0)
   {
      Print("ERROR: FixedCycleProfit must be > 0 in FIXED cycle-profit mode");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxCycleTrades < 1 || InpMaxCycleTrades > MAX_CYCLE_TRADES_HARD_LIMIT)
   {
      PrintFormat("ERROR: MaxCycleTrades must be between 1 and %d", MAX_CYCLE_TRADES_HARD_LIMIT);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxCycleLossMoney <= 0)
   {
      Print("ERROR: MaxCycleLossMoney must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxDailyLossMoney <= 0)
   {
      Print("ERROR: MaxDailyLossMoney must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxDailyLossMoney < InpMaxCycleLossMoney)
   {
      Print("ERROR: MaxDailyLossMoney must be >= MaxCycleLossMoney");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxEquityDrawdownPercent <= 0 || InpMaxEquityDrawdownPercent > 100)
   {
      Print("ERROR: MaxEquityDrawdownPercent must be > 0 and <= 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxMarginUsagePercent <= 0 || InpMaxMarginUsagePercent > 100)
   {
      Print("ERROR: MaxMarginUsagePercent must be > 0 and <= 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRecoveryOnlyFromTrade < 2)
   {
      Print("ERROR: RecoveryOnlyFromTrade must be >= 2");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpMaxSpreadPips <= 0)
   {
      Print("ERROR: MaxSpreadPips must be > 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Close time must be after zone formation time
   int zoneMinutes = InpZoneHour * 60 + InpZoneMinute;
   int closeMinutes = InpCloseHour * 60 + InpCloseMinute;
   if(closeMinutes <= zoneMinutes)
   {
      Print("ERROR: Close time must be after zone formation time");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   // Initialize all modules
   g_zoneManager.Init(g_symbol, InpZoneTimeframe, InpZoneHour, InpZoneMinute);
   
   g_signalEngine.Init(g_symbol, InpEntryTimeframe, 
                       InpBreakoutMode, InpMaxBreakoutPercent, InpMaxBreakoutPips,
                       InpTouchTolerancePips, InpMaxTouchOvershootPips);
   
   g_tradeManager.Init(g_symbol, InpMagicNumber, InpMaxSpreadPips, InpMaxSlippagePoints);
   
   g_slManager.Init(g_symbol, InpSLTimeframe);
   
   g_recoveryManager.Init(g_symbol, InpInitialLot, InpCycleProfitMode, 
                          InpFixedCycleProfit, InpRecoveryOnlyFromTrade,
                          InpMaxAllowedLot, InpMaxCycleTrades, InpMaxCycleLossMoney,
                          InpTakeProfitPips);
   
   g_reentryManager.Init(g_symbol);
   
   g_posLockManager.Init(g_symbol, InpMagicNumber);
   
   g_dailySession.Init(g_symbol, InpCloseHour, InpCloseMinute);
   
   g_newsFilter.Init(g_symbol, InpNewsFilterEnabled, InpNewsCurrencies);
   
   g_riskManager.Init(g_symbol, InpMaxAllowedLot, InpMaxCycleLossMoney,
                      InpMaxDailyLossMoney, InpMaxEquityDrawdownPercent,
                      InpMaxMarginUsagePercent, InpMaxSpreadPips,
                      InpMaxSlippagePoints, InpEmergencyStopEnabled,
                      InpEmergencyStopPips, InpMaxCycleTrades);
   
   g_stateManager.Init(g_symbol, InpMagicNumber);
   
   g_visualManager.Init(g_symbol, InpZoneColor, InpZoneLineThickness, 
                        InpZoneFillOpacity, InpShowPreviousZones,
                        InpPanelX, InpPanelY);
   
   g_statsManager.Init();
   
   // Try to restore state
   if(InpEnableStateSave)
   {
      int posDir = 0;
      if(g_stateManager.LoadState(g_currentState, g_currentZone, g_currentCycle,
                                   g_lastSignal, posDir))
      {
         g_stateRestored = true;
         
         // Restore zone
         if(g_currentZone.IsValid)
            g_zoneManager.SetZone(g_currentZone);
         
         // Restore recovery
         g_recoveryManager.SetTradeNumber(g_currentCycle.TradeNumber);
         g_recoveryManager.SetUnrecoveredLoss(g_currentCycle.UnrecoveredLoss);
         g_recoveryManager.SetTotalCyclePnL(g_currentCycle.TotalCyclePnL);
         g_recoveryManager.SetCycleID(g_currentCycle.CycleID);
         
         // Restore position lock
         if(g_currentCycle.PositionIdentifier > 0)
         {
            if(PositionSelectByTicket(g_currentCycle.PositionIdentifier))
            {
               g_posLockManager.LockPosition(g_currentCycle.PositionIdentifier);
               g_currentCycle.EntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               g_currentCycle.TPPrice = PositionGetDouble(POSITION_TP);
            }
            else
            {
               // Position gone - adjust state
               g_currentCycle.PositionIdentifier = 0;
               g_currentCycle.IsActive = false;
               if(g_currentState == STATE_IN_POSITION)
                  g_currentState = STATE_WAIT_REENTRY;
            }
         }
         
         Print("[EA] State restored successfully");
      }
   }
   
   // Check news for today
   g_newsFilter.Update();
   if(g_newsFilter.IsTodayBlocked())
   {
      if(g_currentState != STATE_IN_POSITION)
         g_currentState = STATE_NEWS_BLOCKED_DAY;
   }
   
   // Validate account type
   string accReason;
   g_posLockManager.ValidateAccountType(accReason);
   if(accReason != "")
      Print("[EA] WARNING: ", accReason);
   
   // Set timer for 1-second updates
   EventSetTimer(1);
   
   g_initialized = true;
   
   PrintFormat("[EA] ZoneRecoveryEA v%s initialized. Symbol=%s Magic=%lu",
               ZRE_VERSION, g_symbol, InpMagicNumber);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Save state
   if(InpEnableStateSave && g_initialized)
   {
      int posDir = (int)g_currentCycle.PositionDir;
      g_stateManager.SaveState(g_currentState, g_currentZone, g_currentCycle,
                               g_lastSignal, posDir);
   }
   
   // Export statistics
   g_statsManager.ExportSummary();
   
   // Clean up chart objects
   if(reason == REASON_REMOVE || reason == REASON_CHARTCLOSE)
   {
      g_visualManager.Cleanup();
   }
   
   EventKillTimer();
   
   PrintFormat("[EA] ZoneRecoveryEA deinitialized. Reason=%d NetProfit=%.2f",
               reason, g_statsManager.GetNetProfit());
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;
   
   // Prevent duplicate processing on same tick
   datetime now = TimeCurrent();
   if(now == g_lastTickTime) return;
   g_lastTickTime = now;
   
   // Update daily session
   g_dailySession.Update();
   
   // Check for day change
   datetime today = GetDayStart(now);
   if(today != g_lastDayChecked)
   {
      OnNewDay(today);
      g_lastDayChecked = today;
   }
   
   // Priority-based state machine processing
   ProcessState();
   
   // Update visual panel
   if(InpShowInfoPanel)
   {
      UpdateVisualPanel();
   }
   
   // Save state periodically
   if(InpEnableStateSave)
   {
      int posDir = (int)g_currentCycle.PositionDir;
      g_stateManager.SaveState(g_currentState, g_currentZone, g_currentCycle,
                               g_lastSignal, posDir);
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_initialized) return;
   
   // Update daily session
   g_dailySession.Update();
   
   // Update risk manager
   g_riskManager.Update();
   
   // Update equity tracking
   g_statsManager.UpdateEquity();
   
   // Check for day change
   datetime today = GetDayStart(TimeCurrent());
   if(today != g_lastDayChecked)
   {
      OnNewDay(today);
      g_lastDayChecked = today;
   }
   
   // Check forced close conditions
   CheckForcedClose();
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(!g_initialized) return;
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Check if this is our deal
      if(trans.order > 0)
      {
         ulong historyDealTicket = trans.deal;
         if(HistoryDealSelect(historyDealTicket))
         {
            long magic = HistoryDealGetInteger(historyDealTicket, DEAL_MAGIC);
            if(magic != (long)InpMagicNumber) return;
            
            long dealEntry = HistoryDealGetInteger(historyDealTicket, DEAL_ENTRY);
            
            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               // Position was closed
               double profit = HistoryDealGetDouble(historyDealTicket, DEAL_PROFIT);
               double commission = HistoryDealGetDouble(historyDealTicket, DEAL_COMMISSION);
               double swap = HistoryDealGetDouble(historyDealTicket, DEAL_SWAP);
               double netProfit = profit + commission + swap;
               double volume = HistoryDealGetDouble(historyDealTicket, DEAL_VOLUME);
               
               string closeReason = DetermineCloseReason(historyDealTicket, g_currentState);
               
               // Only record trade stats here for non-forced closes.
               // Forced closes (DAY_END, NEWS_CLOSE, RISK_HALT) are recorded by 
               // ForceCloseAllPositions() BEFORE the close request.
               bool isForcedClose = (closeReason == "DAY_END" || closeReason == "NEWS_CLOSE" || closeReason == "RISK_HALT");
               if(!isForcedClose && !g_tradeStatsRecorded)
               {
                  g_statsManager.RecordTrade(netProfit, volume,
                     closeReason == "TP", closeReason == "SL",
                     false, false);
               }
               // Reset the flag after processing
               g_tradeStatsRecorded = false;
               
               // Log trade
               TradeRecord record;
               record.TradeID     = historyDealTicket;
               record.CycleID     = g_currentCycle.CycleID;
               record.ZoneID      = g_currentZone.ZoneID;
               record.TradeNumber = g_currentCycle.TradeNumber;
               record.Direction   = g_currentCycle.PositionDir;
               record.Lot         = volume;
               record.EntryPrice  = g_currentCycle.EntryPrice;
               record.ExitPrice   = HistoryDealGetDouble(historyDealTicket, DEAL_PRICE);
               record.TPPrice     = g_currentCycle.TPPrice;
               record.PnL         = netProfit;
               record.CloseReason = closeReason;
               record.OpenTime    = (datetime)HistoryDealGetInteger(historyDealTicket, DEAL_TIME);
               record.CloseTime   = TimeCurrent();
               
               g_stateManager.LogTrade(record);
               
               // Note: Recovery state (RecordSLLoss / RecordTPProfit) is handled
               // by the state machine (ProcessSLClosePending) for SL closes.
               // For TP closes handled here, we do record the profit.
               // For forced closes (DAY_END, NEWS_CLOSE, RISK_HALT), stats are
               // recorded by the state machine before the close request.
               
               // Get position ID from the transaction
               ulong closedPositionID = trans.position;
               
               // Unlock position if it matches our lock
               ulong lockedTicket = g_posLockManager.GetLockedTicket();
               if(lockedTicket > 0 && (lockedTicket == closedPositionID || lockedTicket == 0))
               {
                  g_posLockManager.UnlockPosition();
               }
               else if(closedPositionID == g_currentCycle.PositionIdentifier && g_currentCycle.PositionIdentifier > 0)
               {
                  g_posLockManager.UnlockPosition();
               }
               
               g_positionJustClosed = true;
               g_currentCycle.PositionIdentifier = 0;
               g_currentCycle.IsActive = false;
               
               // Handle TP close: record profit and move to re-entry
               if(closeReason == "TP" && g_currentState == STATE_IN_POSITION)
               {
                  g_recoveryManager.RecordTPProfit(netProfit, volume);
                  
                  // Log cycle completion
                  g_stateManager.LogCycle(g_currentCycle.CycleID, g_currentZone.ZoneID,
                                          g_currentCycle.TradeNumber, g_currentCycle.TotalCyclePnL,
                                          g_currentCycle.UnrecoveredLoss, "TP");
                  g_statsManager.RecordCycleEnd(g_currentCycle.TotalCyclePnL);
                  
                  // Move to re-entry mode
                  g_currentState = STATE_WAIT_REENTRY;
               }
               
               PrintFormat("[EA] Position closed: Reason=%s PnL=%.2f", closeReason, netProfit);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Determine close reason from deal and current state                |
//| Uses state context since broker comments are unreliable           |
//+------------------------------------------------------------------+
string DetermineCloseReason(ulong dealTicket, ENUM_ZONE_STATE currentState)
{
   // First check state context - this is most reliable for EA-initiated closes
   if(currentState == STATE_DAY_END_CLOSE || currentState == STATE_NEWS_FORCED_CLOSE)
   {
      if(currentState == STATE_NEWS_FORCED_CLOSE) return "NEWS_CLOSE";
      return "DAY_END";
   }
   if(currentState == STATE_RISK_HALT)
      return "RISK_HALT";
   if(currentState == STATE_SL_CLOSE_PENDING)
      return "SL";
   
   // Check deal comment as secondary indicator
   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(StringFind(comment, "TP") >= 0) return "TP";
   if(StringFind(comment, "SL") >= 0) return "SL";
   
   // Check if TP was hit based on price comparison
   if(g_currentCycle.TPPrice > 0)
   {
      double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      double point = GetPointSize(g_symbol);
      
      if(g_currentCycle.PositionDir == DIR_BUY)
      {
         if(closePrice >= g_currentCycle.TPPrice - point)
            return "TP";
      }
      else if(g_currentCycle.PositionDir == DIR_SELL)
      {
         if(closePrice <= g_currentCycle.TPPrice + point)
            return "TP";
      }
   }
   
   // If in IN_POSITION and position closed externally (not by us)
   if(currentState == STATE_IN_POSITION)
      return "EXTERNAL_CLOSE";
   
   return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Handle new day                                                    |
//+------------------------------------------------------------------+
void OnNewDay(datetime newDay)
{
   PrintFormat("[EA] New day: %s", TimeToString(newDay, TIME_DATE));
   
   // If there's an open position from previous day, force close it
   ulong ticket;
   ENUM_POSITION_DIRECTION dir;
   double lot, entryPrice;
   
   if(g_tradeManager.HasOpenPosition(ticket, dir, lot, entryPrice))
   {
      Print("[EA] Previous day position found - forcing close");
      
      double pnl = g_tradeManager.GetCurrentPnL(ticket);
      g_tradeManager.ClosePosition(ticket);
      g_posLockManager.UnlockPosition();
      
      g_statsManager.RecordTrade(pnl, lot, false, false, true, false);
      g_tradeStatsRecorded = true;  // Prevent double-counting in OnTradeTransaction
      
      TradeRecord record;
      record.TradeID     = ticket;
      record.CycleID     = g_currentCycle.CycleID;
      record.ZoneID      = g_currentZone.ZoneID;
      record.TradeNumber = g_currentCycle.TradeNumber;
      record.Direction   = dir;
      record.Lot         = lot;
      record.EntryPrice  = entryPrice;
      record.ExitPrice   = 0;
      record.TPPrice     = g_currentCycle.TPPrice;
      record.PnL         = pnl;
      record.CloseReason = "DAY_END_PREV";
      record.OpenTime    = 0;
      record.CloseTime   = TimeCurrent();
      g_stateManager.LogTrade(record);
   }
   
   // Log cycle end BEFORE clearing cycle data (if there was an unfinished cycle)
   if(g_currentCycle.CycleID > 0 && g_currentCycle.TradeNumber > 0)
   {
      g_stateManager.LogCycle(g_currentCycle.CycleID, g_currentZone.ZoneID,
                              g_currentCycle.TradeNumber, g_currentCycle.TotalCyclePnL,
                              g_currentCycle.UnrecoveredLoss, "NEW_DAY");
      g_statsManager.RecordCycleEnd(g_currentCycle.TotalCyclePnL);
   }
   
   // Reset everything for new day - losses NOT carried over
   g_zoneManager.Reset();
   g_signalEngine.ResetForNewDay();
   g_slManager.Reset();
   g_reentryManager.Reset();
   g_dailySession.Reset();
   g_recoveryManager.ResetForNewDay();
   g_statsManager.ResetForNewDay();
   
   // Clear cycle data
   ZeroMemory(g_currentCycle);
   ZeroMemory(g_currentZone);
   g_positionJustClosed = false;
   g_lastSignal = SIGNAL_NONE;
   
   // Check news for today
   g_newsFilter.Update();
   if(g_newsFilter.IsTodayBlocked())
   {
      g_currentState = STATE_NEWS_BLOCKED_DAY;
      Print("[EA] Today is BLOCKED due to high-impact news");
   }
   else
   {
      g_currentState = STATE_WAIT_ZONE;
   }
   
   // Reset risk halt if it was active (daily reset)
   // Note: equity drawdown halt persists across days
   if(g_riskManager.IsRiskHaltActive())
   {
      string reason = g_riskManager.GetRiskHaltReason();
      if(StringFind(reason, "Daily") >= 0)
         g_riskManager.ClearRiskHalt();
   }
}

//+------------------------------------------------------------------+
//| Main state machine processor                                      |
//+------------------------------------------------------------------+
void ProcessState()
{
   // Update risk checks
   if(!g_riskManager.Update())
   {
      if(g_currentState != STATE_RISK_HALT)
      {
         g_currentState = STATE_RISK_HALT;
         Print("[EA] RISK HALT activated: " + g_riskManager.GetRiskHaltReason());
      }
      
      // In risk halt, force close any open position
      ForceCloseAllPositions("RISK_HALT");
      return;
   }
   
   // Check for forced close (news or day end)
   if(CheckForcedClose())
      return;
   
   // State machine
   switch(g_currentState)
   {
      case STATE_WAIT_ZONE:
         ProcessWaitZone();
         break;
         
      case STATE_WAIT_INITIAL_BREAKOUT:
         ProcessWaitBreakout();
         break;
         
      case STATE_IN_POSITION:
         ProcessInPosition();
         break;
         
      case STATE_SL_CLOSE_PENDING:
         ProcessSLClosePending();
         break;
         
      case STATE_REVERSAL_PENDING:
         ProcessReversalPending();
         break;
         
      case STATE_WAIT_REENTRY:
         ProcessWaitReentry();
         break;
         
      case STATE_NEWS_BLOCKED_DAY:
         // Nothing to do - just wait
         break;
         
      case STATE_NEWS_FORCED_CLOSE:
         ForceCloseAllPositions("NEWS_CLOSE");
         g_currentState = STATE_NEWS_BLOCKED_DAY;
         break;
         
      case STATE_DAY_END_CLOSE:
         ForceCloseAllPositions("DAY_END");
         g_currentState = STATE_DAY_COMPLETED;
         break;
         
      case STATE_DAY_COMPLETED:
         // Wait for new day
         break;
         
      case STATE_RISK_HALT:
         // Force close handled above
         break;
         
      case STATE_RECOVERY_REQUIRED:
         ProcessRecoveryRequired();
         break;
   }
}

//+------------------------------------------------------------------+
//| Process WAIT_ZONE state                                           |
//+------------------------------------------------------------------+
void ProcessWaitZone()
{
   if(g_zoneManager.Update())
   {
      // Zone formed
      g_currentZone = g_zoneManager.GetZone();
      g_currentState = STATE_WAIT_INITIAL_BREAKOUT;
      
      // Draw zone on chart
      if(InpShowZoneOnChart)
      {
         datetime visibleTo = TimeCurrent() + 3600 * 4;  // 4 hours ahead
         g_visualManager.DrawZone(g_currentZone, g_currentZone.ZoneTime, visibleTo);
      }
      
      PrintFormat("[EA] Zone formed. State -> WAIT_INITIAL_BREAKOUT");
   }
}

//+------------------------------------------------------------------+
//| Process WAIT_INITIAL_BREAKOUT state                               |
//+------------------------------------------------------------------+
void ProcessWaitBreakout()
{
   // Check if we're in the trading window
   if(!g_dailySession.IsInTradingWindow(g_currentZone.ZoneActiveFrom))
   {
      if(g_dailySession.IsCloseTimeReached())
      {
         g_currentState = STATE_DAY_COMPLETED;
         return;
      }
      return;
   }
   
   // Check for breakout signal
   ENUM_SIGNAL_TYPE signal = g_signalEngine.CheckInitialBreakout(
      g_currentZone.ZoneHigh, g_currentZone.ZoneLow);
   
   if(signal != SIGNAL_NONE)
   {
      // Open the first trade
      OpenTrade(signal, g_recoveryManager.GetInitialLot());
   }
}

//+------------------------------------------------------------------+
//| Process IN_POSITION state                                         |
//+------------------------------------------------------------------+
void ProcessInPosition()
{
   // Check if position still exists
   ulong ticket;
   ENUM_POSITION_DIRECTION dir;
   double lot, entryPrice;
   
   if(!g_tradeManager.HasOpenPosition(ticket, dir, lot, entryPrice))
   {
      // Position was closed externally
      g_posLockManager.UnlockPosition();
      g_currentState = STATE_WAIT_REENTRY;
      g_positionJustClosed = true;
      Print("[EA] Position closed externally");
      return;
   }
   
   // Update cycle data
   g_currentCycle.PositionIdentifier = ticket;
   g_currentCycle.PositionDir = dir;
   g_currentCycle.CurrentLot = lot;
   g_currentCycle.EntryPrice = entryPrice;
   
   // Check for SL signal
   ENUM_SIGNAL_TYPE slSignal = g_slManager.CheckSL(dir, 
      g_currentZone.ZoneHigh, g_currentZone.ZoneLow);
   
   if(slSignal != SIGNAL_NONE)
   {
      g_currentState = STATE_SL_CLOSE_PENDING;
      g_lastSignal = slSignal;
      PrintFormat("[EA] SL signal detected: %s. State -> SL_CLOSE_PENDING",
                  (slSignal == SIGNAL_BUY_REVERSAL) ? "BUY_REVERSAL" : "SELL_REVERSAL");
      return;
   }
}

//+------------------------------------------------------------------+
//| Process SL_CLOSE_PENDING state                                    |
//+------------------------------------------------------------------+
void ProcessSLClosePending()
{
   // Close the current position
   ulong ticket = g_currentCycle.PositionIdentifier;
   if(ticket > 0)
   {
      double pnl = g_tradeManager.GetCurrentPnL(ticket);
      
      if(g_tradeManager.ClosePosition(ticket))
      {
         g_posLockManager.UnlockPosition();
         
         // Record the SL loss
         g_recoveryManager.RecordSLLoss(MathAbs(pnl), g_currentCycle.CurrentLot);
         
         g_statsManager.RecordTrade(pnl, g_currentCycle.CurrentLot, false, true, false, false);
         g_tradeStatsRecorded = true;  // Prevent double-counting in OnTradeTransaction
         
         // Log the trade
         TradeRecord record;
         record.TradeID     = ticket;
         record.CycleID     = g_currentCycle.CycleID;
         record.ZoneID      = g_currentZone.ZoneID;
         record.TradeNumber = g_currentCycle.TradeNumber;
         record.Direction   = g_currentCycle.PositionDir;
         record.Lot         = g_currentCycle.CurrentLot;
         record.EntryPrice  = g_currentCycle.EntryPrice;
         record.ExitPrice   = 0;
         record.TPPrice     = g_currentCycle.TPPrice;
         record.PnL         = pnl;
         record.CloseReason = "SL";
         record.OpenTime    = 0;
         record.CloseTime   = TimeCurrent();
         g_stateManager.LogTrade(record);
         
         g_currentCycle.PositionIdentifier = 0;
         g_currentCycle.IsActive = false;
         
         // Move to reversal
         g_currentState = STATE_REVERSAL_PENDING;
         Print("[EA] SL position closed. State -> REVERSAL_PENDING");
      }
      else
      {
         Print("[EA] Failed to close SL position - retrying");
      }
   }
   else
   {
      // No position to close - already closed
      g_posLockManager.UnlockPosition();
      g_currentState = STATE_REVERSAL_PENDING;
   }
}

//+------------------------------------------------------------------+
//| Process REVERSAL_PENDING state                                    |
//+------------------------------------------------------------------+
void ProcessReversalPending()
{
   // Check if we can open a new position
   string reason;
   if(!g_posLockManager.CanOpenPosition(reason))
   {
      // Wait for position to fully close
      return;
   }
   
   // Calculate recovery lot (loss already recorded in SL_CLOSE_PENDING)
   double recoveryLot = g_recoveryManager.CalculateRecoveryLot();
   
   if(recoveryLot < 0)
   {
      // Recovery lot exceeds limits
      Print("[EA] Recovery lot calculation failed - stopping recovery");
      
      // Log cycle end
      g_stateManager.LogCycle(g_currentCycle.CycleID, g_currentZone.ZoneID,
                              g_currentCycle.TradeNumber, g_currentCycle.TotalCyclePnL,
                              g_currentCycle.UnrecoveredLoss, "RECOVERY_LIMIT");
      g_statsManager.RecordCycleEnd(g_currentCycle.TotalCyclePnL);
      
      g_currentState = STATE_DAY_COMPLETED;
      return;
   }
   
   // Open reversal trade
   ENUM_SIGNAL_TYPE reversalSignal = g_lastSignal;
   
   if(reversalSignal == SIGNAL_BUY_REVERSAL)
      OpenTrade(SIGNAL_BUY_REVERSAL, recoveryLot);
   else if(reversalSignal == SIGNAL_SELL_REVERSAL)
      OpenTrade(SIGNAL_SELL_REVERSAL, recoveryLot);
}

//+------------------------------------------------------------------+
//| Process WAIT_REENTRY state                                        |
//+------------------------------------------------------------------+
void ProcessWaitReentry()
{
   // Activate re-entry if not already
   if(!g_reentryManager.IsActive())
   {
      g_reentryManager.Activate();
   }
   
   // Check if we're in the trading window
   if(!g_dailySession.IsInTradingWindow(g_currentZone.ZoneActiveFrom))
   {
      if(g_dailySession.IsCloseTimeReached())
      {
         g_currentState = STATE_DAY_COMPLETED;
         g_reentryManager.Reset();
         return;
      }
      return;
   }
   
   // Check for re-entry touch signal
   ENUM_SIGNAL_TYPE signal = g_reentryManager.CheckTouch(
      g_currentZone.ZoneHigh, g_currentZone.ZoneLow,
      InpTouchTolerancePips, InpMaxTouchOvershootPips);
   
   if(signal != SIGNAL_NONE)
   {
      // Start new cycle with initial lot
      g_recoveryManager.StartNewCycle();
      g_currentCycle.CycleID = g_recoveryManager.GetCycleID();
      g_currentCycle.TradeNumber = 0;
      
      OpenTrade(signal, g_recoveryManager.GetInitialLot());
   }
}

//+------------------------------------------------------------------+
//| Process RECOVERY_REQUIRED state                                   |
//+------------------------------------------------------------------+
void ProcessRecoveryRequired()
{
   // Similar to reversal pending
   string reason;
   if(!g_posLockManager.CanOpenPosition(reason))
      return;
   
   double recoveryLot = g_recoveryManager.CalculateRecoveryLot();
   if(recoveryLot < 0)
   {
      g_currentState = STATE_DAY_COMPLETED;
      return;
   }
   
   // Continue in opposite direction
   if(g_currentCycle.PositionDir == DIR_BUY)
      OpenTrade(SIGNAL_SELL_REVERSAL, recoveryLot);
   else
      OpenTrade(SIGNAL_BUY_REVERSAL, recoveryLot);
}

//+------------------------------------------------------------------+
//| Open a trade                                                      |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_SIGNAL_TYPE signal, double lot)
{
   // Final checks
   string reason;
   if(!g_posLockManager.CanOpenPosition(reason))
   {
      PrintFormat("[EA] Cannot open trade: %s", reason);
      return false;
   }
   
   // Risk check
   if(!g_riskManager.CanOpenTrade(lot, reason))
   {
      PrintFormat("[EA] Risk check failed: %s", reason);
      return false;
   }
   
   // Normalize lot
   lot = NormalizeLot(g_symbol, lot);
   
   // Determine direction and calculate TP
   bool isBuy = (signal == SIGNAL_BUY_BREAKOUT || 
                 signal == SIGNAL_BUY_REENTRY ||
                 signal == SIGNAL_BUY_REVERSAL);
   
   double pipSize = GetPipSizeForSymbol(g_symbol);
   double tpPrice;
   
   if(isBuy)
   {
      double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      tpPrice = ask + InpTakeProfitPips * pipSize;
      
      ulong ticket;
      if(!g_tradeManager.OpenBuy(lot, tpPrice, ticket))
         return false;
      
      g_currentCycle.PositionDir = DIR_BUY;
      g_currentCycle.PositionIdentifier = ticket;
      g_currentCycle.EntryPrice = ask;
      g_currentCycle.TPPrice = tpPrice;
      g_currentCycle.CurrentLot = lot;
      g_currentCycle.IsActive = true;
   }
   else
   {
      double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      tpPrice = bid - InpTakeProfitPips * pipSize;
      
      ulong ticket;
      if(!g_tradeManager.OpenSell(lot, tpPrice, ticket))
         return false;
      
      g_currentCycle.PositionDir = DIR_SELL;
      g_currentCycle.PositionIdentifier = ticket;
      g_currentCycle.EntryPrice = bid;
      g_currentCycle.TPPrice = tpPrice;
      g_currentCycle.CurrentLot = lot;
      g_currentCycle.IsActive = true;
   }
   
   // Lock position
   g_posLockManager.LockPosition(g_currentCycle.PositionIdentifier);
   
   // Update trade number
   g_currentCycle.TradeNumber++;
   
   // Deactivate re-entry
   g_reentryManager.ResetAfterTrade();
   
   // Reset SL manager and set position open time
   g_slManager.Reset();
   g_slManager.SetPositionOpenTime(TimeCurrent());
   
   // Set state
   g_currentState = STATE_IN_POSITION;
   g_lastSignal = signal;
   
   // Draw entry marker
   if(InpShowZoneOnChart)
      g_visualManager.DrawEntryMarker(TimeCurrent(), g_currentCycle.EntryPrice, isBuy);
   
   PrintFormat("[EA] Trade opened: %s Lot=%.2f TP=%.5f Signal=%d Trade#=%d",
               isBuy ? "BUY" : "SELL", lot, tpPrice, signal, g_currentCycle.TradeNumber);
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for forced close conditions                                 |
//+------------------------------------------------------------------+
bool CheckForcedClose()
{
   // Priority 1: News forced close
   if(g_newsFilter.IsTodayBlocked() && g_currentState == STATE_IN_POSITION)
   {
      ulong ticket;
      ENUM_POSITION_DIRECTION dir;
      double lot, entryPrice;
      
      if(g_tradeManager.HasOpenPosition(ticket, dir, lot, entryPrice))
      {
         g_currentState = STATE_NEWS_FORCED_CLOSE;
         Print("[EA] NEWS forced close activated");
         return true;
      }
      else
      {
         g_currentState = STATE_NEWS_BLOCKED_DAY;
         return true;
      }
   }
   
   // Priority 2: Day end close
   if(g_dailySession.IsCloseTimeReached())
   {
      ulong ticket;
      ENUM_POSITION_DIRECTION dir;
      double lot, entryPrice;
      
      if(g_tradeManager.HasOpenPosition(ticket, dir, lot, entryPrice))
      {
         g_currentState = STATE_DAY_END_CLOSE;
         Print("[EA] Day-end forced close activated");
         return true;
      }
      else if(g_currentState != STATE_DAY_COMPLETED && 
              g_currentState != STATE_NEWS_BLOCKED_DAY &&
              g_currentState != STATE_RISK_HALT)
      {
         // Log cycle end
         if(g_currentCycle.CycleID > 0)
         {
            g_stateManager.LogCycle(g_currentCycle.CycleID, g_currentZone.ZoneID,
                                    g_currentCycle.TradeNumber, g_currentCycle.TotalCyclePnL,
                                    g_currentCycle.UnrecoveredLoss, "DAY_END");
            g_statsManager.RecordCycleEnd(g_currentCycle.TotalCyclePnL);
         }
         
         g_currentState = STATE_DAY_COMPLETED;
         g_reentryManager.Reset();
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Force close all positions                                         |
//+------------------------------------------------------------------+
void ForceCloseAllPositions(string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      
      double pnl = g_tradeManager.GetCurrentPnL(ticket);
      double lot = PositionGetDouble(POSITION_VOLUME);
      
      if(g_tradeManager.ClosePosition(ticket))
      {
         g_posLockManager.UnlockPosition();
         
         g_statsManager.RecordTrade(pnl, lot, false, false,
            reason == "DAY_END", reason == "NEWS_CLOSE");
         g_tradeStatsRecorded = true;  // Prevent double-counting in OnTradeTransaction
         
         // Log
         TradeRecord record;
         record.TradeID     = ticket;
         record.CycleID     = g_currentCycle.CycleID;
         record.ZoneID      = g_currentZone.ZoneID;
         record.TradeNumber = g_currentCycle.TradeNumber;
         record.Direction   = g_currentCycle.PositionDir;
         record.Lot         = lot;
         record.EntryPrice  = g_currentCycle.EntryPrice;
         record.ExitPrice   = 0;
         record.TPPrice     = g_currentCycle.TPPrice;
         record.PnL         = pnl;
         record.CloseReason = reason;
         record.OpenTime    = 0;
         record.CloseTime   = TimeCurrent();
         g_stateManager.LogTrade(record);
         
         // Draw close marker
         if(InpShowZoneOnChart)
            g_visualManager.DrawCloseMarker(TimeCurrent(), 
               PositionGetDouble(POSITION_PRICE_CURRENT), reason);
         
         PrintFormat("[EA] Force closed: %s PnL=%.2f", reason, pnl);
      }
   }
   
   g_currentCycle.PositionIdentifier = 0;
   g_currentCycle.IsActive = false;
}

//+------------------------------------------------------------------+
//| Update visual panel                                               |
//+------------------------------------------------------------------+
void UpdateVisualPanel()
{
   // Calculate display values
   double currentPnL = 0;
   if(g_currentCycle.PositionIdentifier > 0)
      currentPnL = g_tradeManager.GetCurrentPnL(g_currentCycle.PositionIdentifier);
   
   string brokerTime = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   string remainingTime = g_dailySession.GetRemainingTimeString();
   string dayStatus;
   
   if(g_newsFilter.IsTodayBlocked()) dayStatus = "NEWS BLOCKED";
   else if(g_dailySession.IsCloseTimeReached()) dayStatus = "CLOSED";
   else if(g_dailySession.IsWeekend()) dayStatus = "WEEKEND";
   else dayStatus = "ACTIVE";
   
   string newsStatus = g_newsFilter.IsTodayBlocked() ? 
      "BLOCKED (" + IntegerToString(g_newsFilter.GetTodayNewsCount()) + " events)" : "CLEAR";
   
   string nextBlocked = (g_newsFilter.GetNextBlockedDate() > 0) ?
      TimeToString(g_newsFilter.GetNextBlockedDate(), TIME_DATE) : "N/A";
   
   string calendarStatus = g_newsFilter.GetDataStatus();
   
   // Recovery target
   double recoveryTarget = g_currentCycle.UnrecoveredLoss;
   if(g_currentCycle.TradeNumber < InpRecoveryOnlyFromTrade)
      recoveryTarget += InpFixedCycleProfit;
   
   double requiredLot = 0;
   if(g_currentCycle.UnrecoveredLoss > 0)
   {
      // Estimate required lot without changing state
      requiredLot = g_recoveryManager.GetInitialLotValue();  // Approximate for display
      // More accurate calculation would need a separate method
   }
   
   g_visualManager.UpdatePanel(
      g_currentZone, g_currentCycle, g_currentState, currentPnL,
      brokerTime, remainingTime, dayStatus, newsStatus, nextBlocked, calendarStatus,
      g_newsFilter.GetCurrencies(),
      g_statsManager.GetTotalTrades(), g_statsManager.GetTotalCycles(),
      g_statsManager.GetTPCycles(), g_statsManager.GetDayEndCycles(),
      g_statsManager.GetNewsClosures(), g_statsManager.GetMaxLotUsed(),
      g_statsManager.GetMaxEquityDrawdown(), g_statsManager.GetNetProfit(),
      requiredLot, recoveryTarget);
}

//+------------------------------------------------------------------+
//| ChartEvent handler                                                |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Handle chart events if needed
}
//+------------------------------------------------------------------+
