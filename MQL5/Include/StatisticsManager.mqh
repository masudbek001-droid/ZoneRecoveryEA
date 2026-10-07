//+------------------------------------------------------------------+
//|                                            StatisticsManager.mqh |
//|            Statistics collection and export                       |
//+------------------------------------------------------------------+
#ifndef STATISTICS_MANAGER_MQH
#define STATISTICS_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CStatisticsManager class                                          |
//+------------------------------------------------------------------+
class CStatisticsManager
{
private:
   int              m_totalTrades;
   int              m_totalCycles;
   int              m_tpCycles;
   int              m_dayEndCycles;
   int              m_newsClosures;
   int              m_slClosures;
   double           m_maxLotUsed;
   double           m_maxEquityDrawdown;
   double           m_maxBalanceDrawdown;
   double           m_netProfit;
   double           m_grossProfit;
   double           m_grossLoss;
   int              m_maxConsecutiveLosses;
   int              m_currentConsecutiveLosses;
   double           m_totalTradesInCycles;
   double           m_peakEquity;
   double           m_peakBalance;
   
   // Per-cycle tracking
   double           m_cycleProfits[];
   int              m_cycleProfitCount;
   
   string           m_statsFilePath;
   
public:
   CStatisticsManager()
   {
      m_totalTrades          = 0;
      m_totalCycles          = 0;
      m_tpCycles             = 0;
      m_dayEndCycles         = 0;
      m_newsClosures         = 0;
      m_slClosures           = 0;
      m_maxLotUsed           = 0;
      m_maxEquityDrawdown    = 0;
      m_maxBalanceDrawdown   = 0;
      m_netProfit            = 0;
      m_grossProfit          = 0;
      m_grossLoss            = 0;
      m_maxConsecutiveLosses = 0;
      m_currentConsecutiveLosses = 0;
      m_totalTradesInCycles  = 0;
      m_peakEquity           = 0;
      m_peakBalance          = 0;
      m_cycleProfitCount     = 0;
   }
   
   void Init()
   {
      m_statsFilePath = "ZoneRecoveryEA_Stats.csv";
      m_peakEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   //+------------------------------------------------------------------+
   //| Update equity tracking                                           |
   //+------------------------------------------------------------------+
   void UpdateEquity()
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if(equity > m_peakEquity) m_peakEquity = equity;
      if(balance > m_peakBalance) m_peakBalance = balance;
      
      // Calculate drawdown
      if(m_peakEquity > 0)
      {
         double ddPercent = ((m_peakEquity - equity) / m_peakEquity) * 100.0;
         if(ddPercent > m_maxEquityDrawdown) m_maxEquityDrawdown = ddPercent;
      }
      
      if(m_peakBalance > 0)
      {
         double ddPercent = ((m_peakBalance - balance) / m_peakBalance) * 100.0;
         if(ddPercent > m_maxBalanceDrawdown) m_maxBalanceDrawdown = ddPercent;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record a completed trade                                         |
   //+------------------------------------------------------------------+
   void RecordTrade(double profit, double lot, bool isTP, bool isSL, 
                    bool isDayEnd, bool isNewsClose)
   {
      m_totalTrades++;
      m_totalTradesInCycles++;
      m_netProfit += profit;
      
      if(profit >= 0)
      {
         m_grossProfit += profit;
         m_currentConsecutiveLosses = 0;
      }
      else
      {
         m_grossLoss += MathAbs(profit);
         m_currentConsecutiveLosses++;
         if(m_currentConsecutiveLosses > m_maxConsecutiveLosses)
            m_maxConsecutiveLosses = m_currentConsecutiveLosses;
      }
      
      if(lot > m_maxLotUsed) m_maxLotUsed = lot;
      
      if(isTP) m_tpCycles++;
      if(isSL) m_slClosures++;
      if(isDayEnd) m_dayEndCycles++;
      if(isNewsClose) m_newsClosures++;
   }
   
   //+------------------------------------------------------------------+
   //| Record cycle completion                                          |
   //+------------------------------------------------------------------+
   void RecordCycleEnd(double cyclePnL)
   {
      m_totalCycles++;
      m_cycleProfitCount++;
      ArrayResize(m_cycleProfits, m_cycleProfitCount);
      m_cycleProfits[m_cycleProfitCount - 1] = cyclePnL;
   }
   
   //+------------------------------------------------------------------+
   //| Get profit factor                                                |
   //+------------------------------------------------------------------+
   double GetProfitFactor()
   {
      if(m_grossLoss <= 0) return (m_grossProfit > 0) ? 999.99 : 0;
      return m_grossProfit / m_grossLoss;
   }
   
   //+------------------------------------------------------------------+
   //| Get average trades per cycle                                     |
   //+------------------------------------------------------------------+
   double GetAvgTradesPerCycle()
   {
      if(m_totalCycles <= 0) return 0;
      return m_totalTradesInCycles / (double)m_totalCycles;
   }
   
   //+------------------------------------------------------------------+
   //| Get win rate                                                     |
   //+------------------------------------------------------------------+
   double GetWinRate()
   {
      if(m_totalTrades <= 0) return 0;
      return (m_tpCycles / (double)m_totalTrades) * 100.0;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   int GetTotalTrades() const { return m_totalTrades; }
   int GetTotalCycles() const { return m_totalCycles; }
   int GetTPCycles() const { return m_tpCycles; }
   int GetDayEndCycles() const { return m_dayEndCycles; }
   int GetNewsClosures() const { return m_newsClosures; }
   int GetSLClosures() const { return m_slClosures; }
   double GetMaxLotUsed() const { return m_maxLotUsed; }
   double GetMaxEquityDrawdown() const { return m_maxEquityDrawdown; }
   double GetMaxBalanceDrawdown() const { return m_maxBalanceDrawdown; }
   double GetNetProfit() const { return m_netProfit; }
   double GetGrossProfit() const { return m_grossProfit; }
   double GetGrossLoss() const { return m_grossLoss; }
   int GetMaxConsecutiveLosses() const { return m_maxConsecutiveLosses; }
   double GetProfitFactor() const { return GetProfitFactor(); }
   double GetAvgTradesPerCycle() const { return GetAvgTradesPerCycle(); }
   
   //+------------------------------------------------------------------+
   //| Export statistics summary                                        |
   //+------------------------------------------------------------------+
   void ExportSummary()
   {
      int fileHandle = FileOpen(m_statsFilePath, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE) return;
      
      FileWrite(fileHandle, "Metric", "Value");
      FileWrite(fileHandle, "Total Trades", IntegerToString(m_totalTrades));
      FileWrite(fileHandle, "Total Cycles", IntegerToString(m_totalCycles));
      FileWrite(fileHandle, "TP Cycles", IntegerToString(m_tpCycles));
      FileWrite(fileHandle, "Day-End Cycles", IntegerToString(m_dayEndCycles));
      FileWrite(fileHandle, "News Closures", IntegerToString(m_newsClosures));
      FileWrite(fileHandle, "SL Closures", IntegerToString(m_slClosures));
      FileWrite(fileHandle, "Max Lot Used", DoubleToString(m_maxLotUsed, 2));
      FileWrite(fileHandle, "Max Equity Drawdown %", DoubleToString(m_maxEquityDrawdown, 2));
      FileWrite(fileHandle, "Max Balance Drawdown %", DoubleToString(m_maxBalanceDrawdown, 2));
      FileWrite(fileHandle, "Net Profit", DoubleToString(m_netProfit, 2));
      FileWrite(fileHandle, "Gross Profit", DoubleToString(m_grossProfit, 2));
      FileWrite(fileHandle, "Gross Loss", DoubleToString(m_grossLoss, 2));
      FileWrite(fileHandle, "Profit Factor", DoubleToString(GetProfitFactor(), 2));
      FileWrite(fileHandle, "Max Consecutive Losses", IntegerToString(m_maxConsecutiveLosses));
      FileWrite(fileHandle, "Avg Trades per Cycle", DoubleToString(GetAvgTradesPerCycle(), 2));
      FileWrite(fileHandle, "Win Rate %", DoubleToString(GetWinRate(), 2));
      
      FileClose(fileHandle);
      Print("[Statistics] Summary exported to " + m_statsFilePath);
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new day                                                |
   //+------------------------------------------------------------------+
   void ResetForNewDay()
   {
      // Keep cumulative stats, reset daily tracking if needed
      UpdateEquity();
   }
   
   //+------------------------------------------------------------------+
   //| Set state (for restoration)                                      |
   //+------------------------------------------------------------------+
   void SetNetProfit(double profit) { m_netProfit = profit; }
   void SetTotalTrades(int count) { m_totalTrades = count; }
   void SetTotalCycles(int count) { m_totalCycles = count; }
   void SetTPCycles(int count) { m_tpCycles = count; }
   void SetDayEndCycles(int count) { m_dayEndCycles = count; }
   void SetNewsClosures(int count) { m_newsClosures = count; }
};

#endif // STATISTICS_MANAGER_MQH
//+------------------------------------------------------------------+
