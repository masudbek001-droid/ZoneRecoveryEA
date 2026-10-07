//+------------------------------------------------------------------+
//|                                                 TradeManager.mqh |
//|           Order execution, monitoring, and management             |
//+------------------------------------------------------------------+
#ifndef TRADE_MANAGER_MQH
#define TRADE_MANAGER_MQH

#include "CommonDefines.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| CTradeManager class                                               |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   string           m_symbol;
   ulong            m_magic;
   CTrade           m_trade;
   double           m_maxSlippagePoints;
   double           m_maxSpreadPips;
   
   //+------------------------------------------------------------------+
   //| Check if spread is acceptable                                    |
   //+------------------------------------------------------------------+
   bool CheckSpread()
   {
      double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      double point  = GetPointSize(m_symbol);
      double spreadPips = (spread * point) / GetPipSizeForSymbol(m_symbol);
      
      if(spreadPips > m_maxSpreadPips)
      {
         PrintFormat("[TradeManager] Spread too high: %.1f pips (max: %.1f)", 
                     spreadPips, m_maxSpreadPips);
         return false;
      }
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Wait for position to be confirmed by broker                      |
   //+------------------------------------------------------------------+
   bool WaitForPositionOpen(ulong &positionTicket, int timeoutMs = 5000)
   {
      datetime startTime = TimeCurrent();
      while((TimeCurrent() - startTime) * 1000 < timeoutMs)
      {
         // Check for positions with our magic number
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            
            positionTicket = ticket;
            return true;
         }
         Sleep(100);
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Wait for position to be fully closed                             |
   //+------------------------------------------------------------------+
   bool WaitForPositionClose(ulong positionTicket, int timeoutMs = 10000)
   {
      datetime startTime = TimeCurrent();
      while((TimeCurrent() - startTime) * 1000 < timeoutMs)
      {
         bool found = false;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == positionTicket)
            {
               found = true;
               break;
            }
         }
         if(!found) return true;  // Position closed
         Sleep(100);
      }
      return false;
   }

public:
   CTradeManager() {}
   
   void Init(string symbol, ulong magic, double maxSpreadPips, double maxSlippagePoints)
   {
      m_symbol            = symbol;
      m_magic             = magic;
      m_maxSlippagePoints = maxSlippagePoints;
      m_maxSpreadPips     = maxSpreadPips;
      
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints((ulong)maxSlippagePoints);
      m_trade.SetMarginMode();
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
   }
   
   //+------------------------------------------------------------------+
   //| Open a BUY position with TP                                      |
   //+------------------------------------------------------------------+
   bool OpenBuy(double lot, double tpPrice, ulong &positionTicket)
   {
      if(!CheckSpread())
         return false;
      
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      if(ask == 0) return false;
      
      // Normalize TP
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      tpPrice = NormalizeDouble(tpPrice, digits);
      lot = NormalizeLot(m_symbol, lot);
      
      PrintFormat("[TradeManager] Opening BUY: Lot=%.2f Price=%.5f TP=%.5f",
                  lot, ask, tpPrice);
      
      bool result = m_trade.Buy(lot, m_symbol, ask, 0, tpPrice, 
                                "ZRE BUY");
      
      if(!result)
      {
         PrintFormat("[TradeManager] BUY order failed: %d - %s",
                     GetLastError(), m_trade.ResultComment());
         return false;
      }
      
      // Wait for position to appear
      if(!WaitForPositionOpen(positionTicket))
      {
         Print("[TradeManager] Position not confirmed after BUY order");
         return false;
      }
      
      PrintFormat("[TradeManager] BUY opened: Ticket=%u Lot=%.2f", 
                  positionTicket, lot);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Open a SELL position with TP                                     |
   //+------------------------------------------------------------------+
   bool OpenSell(double lot, double tpPrice, ulong &positionTicket)
   {
      if(!CheckSpread())
         return false;
      
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      if(bid == 0) return false;
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      tpPrice = NormalizeDouble(tpPrice, digits);
      lot = NormalizeLot(m_symbol, lot);
      
      PrintFormat("[TradeManager] Opening SELL: Lot=%.2f Price=%.5f TP=%.5f",
                  lot, bid, tpPrice);
      
      bool result = m_trade.Sell(lot, m_symbol, bid, 0, tpPrice, 
                                 "ZRE SELL");
      
      if(!result)
      {
         PrintFormat("[TradeManager] SELL order failed: %d - %s",
                     GetLastError(), m_trade.ResultComment());
         return false;
      }
      
      if(!WaitForPositionOpen(positionTicket))
      {
         Print("[TradeManager] Position not confirmed after SELL order");
         return false;
      }
      
      PrintFormat("[TradeManager] SELL opened: Ticket=%u Lot=%.2f", 
                  positionTicket, lot);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Close position by ticket                                         |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong positionTicket)
   {
      // Select position first
      if(!PositionSelectByTicket(positionTicket))
      {
         PrintFormat("[TradeManager] Position %u not found for closing", positionTicket);
         return false;
      }
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      long posType = PositionGetInteger(POSITION_TYPE);
      
      bool result = false;
      
      if(posType == POSITION_TYPE_BUY)
      {
         result = m_trade.Sell(volume, m_symbol, 0, 0, 0, "ZRE_CLOSE");
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         result = m_trade.Buy(volume, m_symbol, 0, 0, 0, "ZRE_CLOSE");
      }
      
      if(!result)
      {
         PrintFormat("[TradeManager] Close position %u failed: %d - %s",
                     positionTicket, GetLastError(), m_trade.ResultComment());
         return false;
      }
      
      if(!WaitForPositionClose(positionTicket))
      {
         PrintFormat("[TradeManager] Position %u close not confirmed", positionTicket);
         return false;
      }
      
      PrintFormat("[TradeManager] Position %u closed", positionTicket);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Modify TP of existing position                                   |
   //+------------------------------------------------------------------+
   bool ModifyTP(ulong positionTicket, double newTP)
   {
      if(!PositionSelectByTicket(positionTicket))
         return false;
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      newTP = NormalizeDouble(newTP, digits);
      
      double currentSL = PositionGetDouble(POSITION_SL);
      
      if(!m_trade.PositionModify(positionTicket, currentSL, newTP))
      {
         PrintFormat("[TradeManager] Modify TP failed: %d - %s",
                     GetLastError(), m_trade.ResultComment());
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if we have any open position with our magic                |
   //+------------------------------------------------------------------+
   bool HasOpenPosition(ulong &ticket, ENUM_POSITION_DIRECTION &dir, double &lot, double &entryPrice)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         ticket = t;
         long posType = PositionGetInteger(POSITION_TYPE);
         dir = (posType == POSITION_TYPE_BUY) ? DIR_BUY : DIR_SELL;
         lot = PositionGetDouble(POSITION_VOLUME);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         return true;
      }
      
      ticket = 0;
      dir = DIR_NONE;
      lot = 0;
      entryPrice = 0;
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get current PnL of open position                                 |
   //+------------------------------------------------------------------+
   double GetCurrentPnL(ulong positionTicket)
   {
      if(!PositionSelectByTicket(positionTicket))
         return 0;
      return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   
   //+------------------------------------------------------------------+
   //| Get entry price of open position                                 |
   //+------------------------------------------------------------------+
   double GetPositionEntryPrice(ulong positionTicket)
   {
      if(!PositionSelectByTicket(positionTicket))
         return 0;
      return PositionGetDouble(POSITION_PRICE_OPEN);
   }
   
   //+------------------------------------------------------------------+
   //| Get TP of open position                                          |
   //+------------------------------------------------------------------+
   double GetPositionTP(ulong positionTicket)
   {
      if(!PositionSelectByTicket(positionTicket))
         return 0;
      return PositionGetDouble(POSITION_TP);
   }
   
   //+------------------------------------------------------------------+
   //| Get pending orders count with our magic                          |
   //+------------------------------------------------------------------+
   int GetPendingOrdersCount()
   {
      int count = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetInteger(ORDER_MAGIC) != (long)m_magic) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
         count++;
      }
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Check if there are any unprocessed trade transactions            |
   //+------------------------------------------------------------------+
   bool HasPendingTradeOperations()
   {
      return (GetPendingOrdersCount() > 0);
   }
   
   //+------------------------------------------------------------------+
   //| Calculate profit for a given lot and price movement              |
   //+------------------------------------------------------------------+
   double CalculateProfit(string symbol, double lot, double openPrice, double closePrice)
   {
      double profit = 0;
      if(!OrderCalcProfit(ORDER_TYPE_BUY, symbol, lot, openPrice, closePrice, profit))
      {
         PrintFormat("[TradeManager] OrderCalcProfit failed: %d", GetLastError());
         return 0;
      }
      return profit;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   ulong GetMagic() const { return m_magic; }
   string GetSymbol() const { return m_symbol; }
};

#endif // TRADE_MANAGER_MQH
//+------------------------------------------------------------------+
