//+------------------------------------------------------------------+
//|                                              StopLossManager.mqh |
//|          Virtual SL based on candle close beyond zone boundary    |
//+------------------------------------------------------------------+
#ifndef STOP_LOSS_MANAGER_MQH
#define STOP_LOSS_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CStopLossManager class                                            |
//+------------------------------------------------------------------+
class CStopLossManager
{
private:
   string              m_symbol;
   ENUM_TIMEFRAMES     m_slTimeframe;
   
   // Track the last processed SL bar to avoid duplicate signals
   datetime            m_lastSLBarTime;
   bool                m_slSignalTriggered;
   ENUM_SIGNAL_TYPE    m_slSignal;
   
   // Position open time - SL candles must close AFTER this time
   datetime            m_positionOpenTime;
   
   //+------------------------------------------------------------------+
   //| Check if the last closed candle triggered SL for BUY position   |
   //| BUY SL: candle close < ZoneLow (body only)                       |
   //+------------------------------------------------------------------+
   bool CheckBuySL(double zoneLow)
   {
      // Need at least bar index 1 (last closed)
      datetime bar1Time = iTime(m_symbol, m_slTimeframe, 1);
      if(bar1Time == 0) return false;
      
      // Prevent processing same bar twice
      if(bar1Time == m_lastSLBarTime) return false;
      
      // The candle must have CLOSED after the position was opened
      // The candle at index 1 closes at the open time of bar 0
      datetime bar1CloseTime = iTime(m_symbol, m_slTimeframe, 0);  // This is when bar 1 "closed" (= bar 0 opened)
      if(bar1CloseTime <= m_positionOpenTime) return false;
      
      double close1 = iClose(m_symbol, m_slTimeframe, 1);
      
      // SL for BUY: candle body closes below ZoneLow
      // Only body counts - open must be above or at ZoneLow
      double open1 = iOpen(m_symbol, m_slTimeframe, 1);
      
      if(close1 < zoneLow && open1 >= zoneLow)
      {
         m_lastSLBarTime = bar1Time;
         m_slSignalTriggered = true;
         m_slSignal = SIGNAL_SELL_REVERSAL;
         PrintFormat("[SLManager] BUY SL triggered: Close=%.5f < ZoneLow=%.5f at %s",
                     close1, zoneLow, TimeToString(bar1Time, TIME_DATE|TIME_MINUTES));
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if the last closed candle triggered SL for SELL position  |
   //| SELL SL: candle close > ZoneHigh (body only)                     |
   //+------------------------------------------------------------------+
   bool CheckSellSL(double zoneHigh)
   {
      datetime bar1Time = iTime(m_symbol, m_slTimeframe, 1);
      if(bar1Time == 0) return false;
      
      if(bar1Time == m_lastSLBarTime) return false;
      
      // The candle must have CLOSED after the position was opened
      datetime bar1CloseTime = iTime(m_symbol, m_slTimeframe, 0);
      if(bar1CloseTime <= m_positionOpenTime) return false;
      
      double close1 = iClose(m_symbol, m_slTimeframe, 1);
      double open1  = iOpen(m_symbol, m_slTimeframe, 1);
      
      // SL for SELL: candle body closes above ZoneHigh
      if(close1 > zoneHigh && open1 <= zoneHigh)
      {
         m_lastSLBarTime = bar1Time;
         m_slSignalTriggered = true;
         m_slSignal = SIGNAL_BUY_REVERSAL;
         PrintFormat("[SLManager] SELL SL triggered: Close=%.5f > ZoneHigh=%.5f at %s",
                     close1, zoneHigh, TimeToString(bar1Time, TIME_DATE|TIME_MINUTES));
         return true;
      }
      
      return false;
   }

public:
   CStopLossManager()
   {
      m_lastSLBarTime     = 0;
      m_slSignalTriggered = false;
      m_slSignal          = SIGNAL_NONE;
      m_positionOpenTime  = 0;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES slTimeframe)
   {
      m_symbol        = symbol;
      m_slTimeframe   = slTimeframe;
   }
   
   //+------------------------------------------------------------------+
   //| Set position open time for SL validation                         |
   //+------------------------------------------------------------------+
   void SetPositionOpenTime(datetime openTime)
   {
      m_positionOpenTime = openTime;
   }
   
   //+------------------------------------------------------------------+
   //| Update SL check - call every tick                                |
   //| Returns SIGNAL_NONE, SIGNAL_BUY_REVERSAL, or SIGNAL_SELL_REVERSAL|
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE CheckSL(ENUM_POSITION_DIRECTION posDir, double zoneHigh, double zoneLow)
   {
      m_slSignalTriggered = false;
      m_slSignal = SIGNAL_NONE;
      
      if(posDir == DIR_BUY)
      {
         if(CheckBuySL(zoneLow))
            return SIGNAL_SELL_REVERSAL;
      }
      else if(posDir == DIR_SELL)
      {
         if(CheckSellSL(zoneHigh))
            return SIGNAL_BUY_REVERSAL;
      }
      
      return SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new cycle                                              |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_lastSLBarTime     = 0;
      m_slSignalTriggered = false;
      m_slSignal          = SIGNAL_NONE;
      m_positionOpenTime  = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsSLTriggered() const { return m_slSignalTriggered; }
   ENUM_SIGNAL_TYPE GetSLSignal() const { return m_slSignal; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_slTimeframe; }
   
   //+------------------------------------------------------------------+
   //| Set state (for restoration)                                      |
   //+------------------------------------------------------------------+
   void SetLastSLBarTime(datetime time) { m_lastSLBarTime = time; }
};

#endif // STOP_LOSS_MANAGER_MQH
//+------------------------------------------------------------------+
