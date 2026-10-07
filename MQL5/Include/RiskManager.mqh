//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|            Risk management and safety limits                      |
//+------------------------------------------------------------------+
#ifndef RISK_MANAGER_MQH
#define RISK_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CRiskManager class                                                |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   string           m_symbol;
   double           m_maxAllowedLot;
   double           m_maxCycleLossMoney;
   double           m_maxDailyLossMoney;
   double           m_maxEquityDrawdownPercent;
   double           m_maxMarginUsagePercent;
   double           m_maxSpreadPips;
   double           m_maxSlippagePoints;
   bool             m_emergencyStopEnabled;
   double           m_emergencyStopPips;
   int              m_maxCycleTrades;
   
   bool             m_riskHaltActive;
   string           m_riskHaltReason;
   
   // Daily tracking
   double           m_dailyStartBalance;
   double           m_dailyRealizedPnL;
   datetime         m_dailyStartDay;
   
   //+------------------------------------------------------------------+
   //| Calculate current equity drawdown percentage                     |
   //+------------------------------------------------------------------+
   double CalculateEquityDrawdownPercent()
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      
      if(balance <= 0) return 100;
      
      double drawdown = ((balance - equity) / balance) * 100.0;
      return drawdown;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate margin usage percentage                                |
   //+------------------------------------------------------------------+
   double CalculateMarginUsagePercent()
   {
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      if(equity <= 0) return 100;
      
      return (margin / equity) * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate required margin for a given lot                        |
   //+------------------------------------------------------------------+
   double CalculateRequiredMargin(double lot)
   {
      double margin = 0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, lot, 
                          SymbolInfoDouble(m_symbol, SYMBOL_ASK), margin))
      {
         return 0;
      }
      return margin;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate daily loss including unrealized                        |
   //+------------------------------------------------------------------+
   double CalculateDailyLoss()
   {
      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double unrealizedPnL  = 0;
      
      // Sum unrealized PnL of open positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         unrealizedPnL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
      
      double totalPnL = (currentBalance - m_dailyStartBalance) + unrealizedPnL;
      return (totalPnL < 0) ? -totalPnL : 0;  // Return as positive loss
   }

public:
   CRiskManager()
   {
      m_riskHaltActive    = false;
      m_riskHaltReason    = "";
      m_dailyStartBalance = 0;
      m_dailyRealizedPnL  = 0;
      m_dailyStartDay     = 0;
   }
   
   void Init(string symbol, double maxAllowedLot, double maxCycleLossMoney,
             double maxDailyLossMoney, double maxEquityDrawdownPercent,
             double maxMarginUsagePercent, double maxSpreadPips,
             double maxSlippagePoints, bool emergencyStopEnabled,
             double emergencyStopPips, int maxCycleTrades)
   {
      m_symbol                  = symbol;
      m_maxAllowedLot           = maxAllowedLot;
      m_maxCycleLossMoney       = maxCycleLossMoney;
      m_maxDailyLossMoney       = maxDailyLossMoney;
      m_maxEquityDrawdownPercent = maxEquityDrawdownPercent;
      m_maxMarginUsagePercent   = maxMarginUsagePercent;
      m_maxSpreadPips           = maxSpreadPips;
      m_maxSlippagePoints       = maxSlippagePoints;
      m_emergencyStopEnabled    = emergencyStopEnabled;
      m_emergencyStopPips       = emergencyStopPips;
      m_maxCycleTrades          = maxCycleTrades;
      
      // Initialize daily tracking
      m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dailyStartDay     = GetDayStart(TimeCurrent());
   }
   
   //+------------------------------------------------------------------+
   //| Update risk status - call every tick                             |
   //+------------------------------------------------------------------+
   bool Update()
   {
      if(m_riskHaltActive) return false;
      
      // Check if day has changed - reset daily tracking
      datetime today = GetDayStart(TimeCurrent());
      if(today != m_dailyStartDay)
      {
         m_dailyStartDay     = today;
         m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_dailyRealizedPnL  = 0;
      }
      
      // Check equity drawdown
      if(m_maxEquityDrawdownPercent > 0)
      {
         double dd = CalculateEquityDrawdownPercent();
         if(dd > m_maxEquityDrawdownPercent)
         {
            SetRiskHalt(StringFormat("Equity drawdown %.1f%% exceeds limit %.1f%%",
                                     dd, m_maxEquityDrawdownPercent));
            return false;
         }
      }
      
      // Check margin usage
      if(m_maxMarginUsagePercent > 0)
      {
         double marginUsage = CalculateMarginUsagePercent();
         if(marginUsage > m_maxMarginUsagePercent)
         {
            SetRiskHalt(StringFormat("Margin usage %.1f%% exceeds limit %.1f%%",
                                     marginUsage, m_maxMarginUsagePercent));
            return false;
         }
      }
      
      // Check daily loss
      if(m_maxDailyLossMoney > 0)
      {
         double dailyLoss = CalculateDailyLoss();
         if(dailyLoss > m_maxDailyLossMoney)
         {
            SetRiskHalt(StringFormat("Daily loss %.2f exceeds limit %.2f",
                                     dailyLoss, m_maxDailyLossMoney));
            return false;
         }
      }
      
      // Check emergency stop
      if(m_emergencyStopEnabled && m_emergencyStopPips > 0)
      {
         double currentPnLPips = GetCurrentPnLPips();
         if(currentPnLPips < -m_emergencyStopPips)
         {
            SetRiskHalt(StringFormat("Emergency stop: PnL %.1f pips exceeds -%.1f pips",
                                     currentPnLPips, m_emergencyStopPips));
            return false;
         }
      }
      
      return true;  // All risk checks passed
   }
   
   //+------------------------------------------------------------------+
   //| Check if new trade is allowed                                    |
   //+------------------------------------------------------------------+
   bool CanOpenTrade(double lot, string &reason)
   {
      reason = "";
      
      if(m_riskHaltActive)
      {
         reason = "RISK HALT: " + m_riskHaltReason;
         return false;
      }
      
      // Check lot limit
      if(lot > m_maxAllowedLot)
      {
         reason = StringFormat("Lot %.2f exceeds max allowed %.2f", lot, m_maxAllowedLot);
         return false;
      }
      
      // Check margin for this trade
      double requiredMargin = CalculateRequiredMargin(lot);
      if(requiredMargin > 0)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double currentMargin = AccountInfoDouble(ACCOUNT_MARGIN);
         double freeMargin = equity - currentMargin;
         
         if(requiredMargin > freeMargin * 0.8)  // Keep 20% buffer
         {
            reason = StringFormat("Insufficient margin: need %.2f, free %.2f",
                                  requiredMargin, freeMargin);
            return false;
         }
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get current PnL in pips                                          |
   //+------------------------------------------------------------------+
   double GetCurrentPnLPips()
   {
      double totalPnL = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         totalPnL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
      
      // Convert to pips (approximate)
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickValue <= 0 || tickSize <= 0) return 0;
      
      double pipSize = GetPipSizeForSymbol(m_symbol);
      double pipValue = (tickValue / tickSize) * pipSize;
      if(pipValue <= 0) return 0;
      
      return totalPnL / pipValue;
   }
   
   //+------------------------------------------------------------------+
   //| Set risk halt                                                    |
   //+------------------------------------------------------------------+
   void SetRiskHalt(string reason)
   {
      if(!m_riskHaltActive)
      {
         m_riskHaltActive = true;
         m_riskHaltReason = reason;
         PrintFormat("[RiskManager] RISK HALT ACTIVATED: %s", reason);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Clear risk halt (manual reset)                                   |
   //+------------------------------------------------------------------+
   void ClearRiskHalt()
   {
      m_riskHaltActive = false;
      m_riskHaltReason = "";
      Print("[RiskManager] Risk halt cleared");
   }
   
   //+------------------------------------------------------------------+
   //| Record realized PnL                                              |
   //+------------------------------------------------------------------+
   void RecordRealizedPnL(double profit)
   {
      m_dailyRealizedPnL += profit;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsRiskHaltActive() const { return m_riskHaltActive; }
   string GetRiskHaltReason() const { return m_riskHaltReason; }
   double GetMaxAllowedLot() const { return m_maxAllowedLot; }
   double GetMaxCycleLossMoney() const { return m_maxCycleLossMoney; }
   double GetMaxDailyLossMoney() const { return m_maxDailyLossMoney; }
   double GetDailyStartBalance() const { return m_dailyStartBalance; }
   double GetDailyRealizedPnL() const { return m_dailyRealizedPnL; }
   int GetMaxCycleTrades() const { return m_maxCycleTrades; }
   bool IsEmergencyStopEnabled() const { return m_emergencyStopEnabled; }
   double GetEmergencyStopPips() const { return m_emergencyStopPips; }
   
   //+------------------------------------------------------------------+
   //| Set state (for restoration)                                      |
   //+------------------------------------------------------------------+
   void SetDailyStartBalance(double balance) { m_dailyStartBalance = balance; }
   void SetDailyStartDay(datetime day) { m_dailyStartDay = day; }
};

#endif // RISK_MANAGER_MQH
//+------------------------------------------------------------------+
