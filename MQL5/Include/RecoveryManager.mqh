//+------------------------------------------------------------------+
//|                                               RecoveryManager.mqh|
//|            Dynamic lot calculation and recovery algorithm         |
//+------------------------------------------------------------------+
#ifndef RECOVERY_MANAGER_MQH
#define RECOVERY_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CRecoveryManager class                                            |
//+------------------------------------------------------------------+
class CRecoveryManager
{
private:
   string                  m_symbol;
   double                  m_initialLot;
   ENUM_CYCLE_PROFIT_MODE  m_cycleProfitMode;
   double                  m_fixedCycleProfit;
   int                     m_recoveryOnlyFromTrade;  // Starting from which trade number, P=0
   double                  m_maxAllowedLot;
   int                     m_maxCycleTrades;
   double                  m_maxCycleLossMoney;
   double                  m_takeProfitPips;
   
   // Cycle state
   int                     m_tradeNumber;      // Current trade number in cycle (1-based)
   double                  m_unrecoveredLoss;  // L - accumulated unrealized loss
   double                  m_totalCyclePnL;    // Total realized + unrealized PnL for cycle
   ulong                   m_cycleID;
   ulong                   m_cycleCounter;
   
   //+------------------------------------------------------------------+
   //| Calculate expected profit at TP for given lot                    |
   //+------------------------------------------------------------------+
   double CalculateExpectedProfit(double lot)
   {
      double pipPrice = GetPipSizeForSymbol(m_symbol);
      double tpPrice  = m_takeProfitPips * pipPrice;
      
      double openPrice  = 1.0;  // Reference price
      double closePrice = openPrice + tpPrice;
      
      double profit = 0;
      if(!OrderCalcProfit(ORDER_TYPE_BUY, m_symbol, lot, openPrice, closePrice, profit))
      {
         PrintFormat("[RecoveryManager] OrderCalcProfit failed: %d", GetLastError());
         return 0;
      }
      return profit;
   }

public:
   CRecoveryManager()
   {
      m_tradeNumber     = 0;
      m_unrecoveredLoss = 0;
      m_totalCyclePnL   = 0;
      m_cycleID         = 0;
      m_cycleCounter    = 0;
   }
   
   void Init(string symbol, double initialLot, 
             ENUM_CYCLE_PROFIT_MODE cycleProfitMode, double fixedCycleProfit,
             int recoveryOnlyFromTrade, double maxAllowedLot,
             int maxCycleTrades, double maxCycleLossMoney,
             double takeProfitPips)
   {
      m_symbol               = symbol;
      m_initialLot           = initialLot;
      m_cycleProfitMode      = cycleProfitMode;
      m_fixedCycleProfit     = fixedCycleProfit;
      m_recoveryOnlyFromTrade = recoveryOnlyFromTrade;
      m_maxAllowedLot        = maxAllowedLot;
      m_maxCycleTrades       = maxCycleTrades;
      m_maxCycleLossMoney    = maxCycleLossMoney;
      m_takeProfitPips       = takeProfitPips;
   }
   
   //+------------------------------------------------------------------+
   //| Start a new cycle                                                |
   //+------------------------------------------------------------------+
   void StartNewCycle()
   {
      m_cycleCounter++;
      m_cycleID         = m_cycleCounter;
      m_tradeNumber     = 0;
      m_unrecoveredLoss = 0;
      m_totalCyclePnL   = 0;
      
      PrintFormat("[RecoveryManager] New cycle started: CycleID=%lu", m_cycleID);
   }
   
   //+------------------------------------------------------------------+
   //| Get lot for the first trade in cycle                             |
   //+------------------------------------------------------------------+
   double GetInitialLot()
   {
      return NormalizeLot(m_symbol, m_initialLot);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate lot for recovery trade after SL                        |
   //| E(V) >= L + P                                                    |
   //| Where L = unrecovered loss, P = profit target (0 if recovery-only)|
   //| Note: Loss must be added via RecordSLLoss BEFORE calling this    |
   //+------------------------------------------------------------------+
   double CalculateRecoveryLot()
   {
      // Increment trade number for the new recovery trade
      m_tradeNumber++;
      
      // Check cycle limits
      if(m_tradeNumber > m_maxCycleTrades)
      {
         Print("[RecoveryManager] Max cycle trades exceeded");
         m_tradeNumber--;
         return -1;
      }
      
      if(m_unrecoveredLoss > m_maxCycleLossMoney && m_maxCycleLossMoney > 0)
      {
         Print("[RecoveryManager] Max cycle loss exceeded");
         m_tradeNumber--;
         return -1;
      }
      
      // Determine profit target P
      double P = m_fixedCycleProfit;
      
      // If we're at or past the recovery-only threshold, P = 0
      if(m_tradeNumber >= m_recoveryOnlyFromTrade)
      {
         P = 0;
      }
      
      // L = total unrecovered loss (already updated by RecordSLLoss)
      double L = m_unrecoveredLoss;
      
      // Target: E(V) >= L + P
      double targetProfit = L + P;
      
      if(targetProfit <= 0)
      {
         // No loss to recover, use initial lot
         return GetInitialLot();
      }
      
      // Iterative search for the lot that gives us the target profit
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot = m_maxAllowedLot;
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      
      double bestLot = -1;
      
      double testLot = minLot;
      int maxIterations = (int)((maxLot - minLot) / lotStep) + 1;
      int iterations = 0;
      
      while(testLot <= maxLot && iterations < maxIterations)
      {
         double expectedProfit = CalculateExpectedProfit(testLot);
         if(expectedProfit >= targetProfit)
         {
            bestLot = testLot;
            break;
         }
         testLot += lotStep;
         iterations++;
      }
      
      if(bestLot < 0)
      {
         // Even max lot can't cover the target
         PrintFormat("[RecoveryManager] Required profit %.2f cannot be achieved with max lot %.2f",
                     targetProfit, maxLot);
         m_tradeNumber--;
         return -1;
      }
      
      // Normalize the lot
      bestLot = NormalizeLot(m_symbol, bestLot);
      
      if(bestLot > m_maxAllowedLot)
      {
         PrintFormat("[RecoveryManager] Required lot %.2f exceeds max allowed %.2f",
                     bestLot, m_maxAllowedLot);
         m_tradeNumber--;
         return -1;
      }
      
      PrintFormat("[RecoveryManager] Recovery lot calculated: Trade#=%d L=%.2f P=%.2f Lot=%.2f",
                  m_tradeNumber, L, P, bestLot);
      
      return bestLot;
   }
   
   //+------------------------------------------------------------------+
   //| Record TP profit - cycle completes successfully                  |
   //+------------------------------------------------------------------+
   void RecordTPProfit(double profit, double lot)
   {
      m_tradeNumber++;
      m_totalCyclePnL += profit;
      
      // If profit covers all losses and target, cycle is complete
      if(m_totalCyclePnL >= m_unrecoveredLoss)
      {
         m_unrecoveredLoss = 0;
      }
      
      PrintFormat("[RecoveryManager] TP recorded: Profit=%.2f TotalPnL=%.2f Trade#=%d",
                  profit, m_totalCyclePnL, m_tradeNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Record SL loss                                                   |
   //+------------------------------------------------------------------+
   void RecordSLLoss(double loss, double lot)
   {
      m_totalCyclePnL -= loss;  // Loss is positive number, subtract
      PrintFormat("[RecoveryManager] SL recorded: Loss=%.2f TotalPnL=%.2f UnrecoveredLoss=%.2f Trade#=%d",
                  loss, m_totalCyclePnL, m_unrecoveredLoss, m_tradeNumber);
   }
   
   //+------------------------------------------------------------------+
   //| Check if cycle is complete (TP achieved with recovery)           |
   //+------------------------------------------------------------------+
   bool IsCycleComplete()
   {
      return (m_unrecoveredLoss <= 0 && m_tradeNumber > 0);
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new day - losses are NOT carried over                  |
   //+------------------------------------------------------------------+
   void ResetForNewDay()
   {
      PrintFormat("[RecoveryManager] Day reset. Final cycle PnL: %.2f Unrecovered: %.2f",
                  m_totalCyclePnL, m_unrecoveredLoss);
      
      // Start fresh - new day, new cycle, no loss carryover
      m_tradeNumber     = 0;
      m_unrecoveredLoss = 0;
      m_totalCyclePnL   = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Check if max cycle loss exceeded                                 |
   //+------------------------------------------------------------------+
   bool IsCycleLossExceeded()
   {
      if(m_maxCycleLossMoney <= 0) return false;
      return (m_unrecoveredLoss > m_maxCycleLossMoney);
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   int GetTradeNumber() const { return m_tradeNumber; }
   double GetUnrecoveredLoss() const { return m_unrecoveredLoss; }
   double GetTotalCyclePnL() const { return m_totalCyclePnL; }
   ulong GetCycleID() const { return m_cycleID; }
   double GetInitialLotValue() const { return m_initialLot; }
   double GetMaxAllowedLot() const { return m_maxAllowedLot; }
   int GetMaxCycleTrades() const { return m_maxCycleTrades; }
   double GetTakeProfitPips() const { return m_takeProfitPips; }
   
   //+------------------------------------------------------------------+
   //| Set state (for restoration)                                      |
   //+------------------------------------------------------------------+
   void SetTradeNumber(int num) { m_tradeNumber = num; }
   void SetUnrecoveredLoss(double loss) { m_unrecoveredLoss = loss; }
   void SetTotalCyclePnL(double pnl) { m_totalCyclePnL = pnl; }
   void SetCycleID(ulong id) { m_cycleID = id; }
   void SetCycleCounter(ulong counter) { m_cycleCounter = counter; }
};

#endif // RECOVERY_MANAGER_MQH
//+------------------------------------------------------------------+
