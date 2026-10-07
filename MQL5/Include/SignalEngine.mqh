//+------------------------------------------------------------------+
//|                                                  SignalEngine.mqh|
//|           Breakout and Re-entry signal detection                  |
//+------------------------------------------------------------------+
#ifndef SIGNAL_ENGINE_MQH
#define SIGNAL_ENGINE_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CSignalEngine class                                               |
//+------------------------------------------------------------------+
class CSignalEngine
{
private:
   string              m_symbol;
   ENUM_TIMEFRAMES     m_entryTimeframe;
   ENUM_BREAKOUT_MODE  m_breakoutMode;
   double              m_maxBreakoutPercent;
   double              m_maxBreakoutPips;
   
   // Re-entry parameters
   double              m_touchTolerancePips;
   double              m_maxTouchOvershootPips;
   
   // State tracking
   bool                m_initialBreakoutDone;
   ENUM_SIGNAL_TYPE    m_lastSignal;
   datetime            m_lastSignalBarTime;
   
   // Re-entry tracking
   bool                m_priceWentOutside;     // Price has gone outside zone
   ENUM_POSITION_DIRECTION m_outsideDirection; // Which side
   
   //+------------------------------------------------------------------+
   //| Check breakout distance filter                                   |
   //+------------------------------------------------------------------+
   bool CheckBreakoutDistance(double zoneHigh, double zoneLow, 
                               double closePrice, bool isBuyBreakout)
   {
      if(m_breakoutMode == BREAKOUT_MODE_NONE)
         return true;
      
      double zoneSize = zoneHigh - zoneLow;
      double breakoutDistance;
      double maxDistance;
      
      if(isBuyBreakout)
         breakoutDistance = closePrice - zoneHigh;
      else
         breakoutDistance = zoneLow - closePrice;
      
      if(m_breakoutMode == BREAKOUT_MODE_PERCENT)
      {
         maxDistance = zoneSize * (m_maxBreakoutPercent / 100.0);
      }
      else // FIXED_PIPS
      {
         maxDistance = PipsToPrice(m_symbol, m_maxBreakoutPips);
      }
      
      return (breakoutDistance <= maxDistance);
   }

public:
   CSignalEngine()
   {
      m_initialBreakoutDone = false;
      m_lastSignal          = SIGNAL_NONE;
      m_lastSignalBarTime   = 0;
      m_priceWentOutside    = false;
      m_outsideDirection    = DIR_NONE;
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES entryTimeframe,
             ENUM_BREAKOUT_MODE breakoutMode,
             double maxBreakoutPercent, double maxBreakoutPips,
             double touchTolerancePips, double maxTouchOvershootPips)
   {
      m_symbol              = symbol;
      m_entryTimeframe      = entryTimeframe;
      m_breakoutMode        = breakoutMode;
      m_maxBreakoutPercent  = maxBreakoutPercent;
      m_maxBreakoutPips     = maxBreakoutPips;
      m_touchTolerancePips  = touchTolerancePips;
      m_maxTouchOvershootPips = maxTouchOvershootPips;
   }
   
   //+------------------------------------------------------------------+
   //| Check for initial breakout signal                                |
   //| Returns SIGNAL_NONE, SIGNAL_BUY_BREAKOUT, or SIGNAL_SELL_BREAKOUT|
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE CheckInitialBreakout(double zoneHigh, double zoneLow)
   {
      if(m_initialBreakoutDone)
         return SIGNAL_NONE;
      
      // Wait for entry timeframe candle to close
      // We need at least 2 candles (index 0 = current, 1 = last closed)
      datetime bar1Time = iTime(m_symbol, m_entryTimeframe, 1);
      if(bar1Time == 0) return SIGNAL_NONE;
      
      // Prevent processing same bar twice
      if(bar1Time == m_lastSignalBarTime)
         return SIGNAL_NONE;
      
      double open1  = iOpen(m_symbol, m_entryTimeframe, 1);
      double close1 = iClose(m_symbol, m_entryTimeframe, 1);
      
      ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;
      
      // BUY breakout: Open <= ZoneHigh AND Close > ZoneHigh (body crosses above)
      if(open1 <= zoneHigh && close1 > zoneHigh)
      {
         // Check breakout distance filter
         if(CheckBreakoutDistance(zoneHigh, zoneLow, close1, true))
         {
            signal = SIGNAL_BUY_BREAKOUT;
         }
      }
      // SELL breakout: Open >= ZoneLow AND Close < ZoneLow (body crosses below)
      else if(open1 >= zoneLow && close1 < zoneLow)
      {
         if(CheckBreakoutDistance(zoneHigh, zoneLow, close1, false))
         {
            signal = SIGNAL_SELL_BREAKOUT;
         }
      }
      
      if(signal != SIGNAL_NONE)
      {
         m_initialBreakoutDone = true;
         m_lastSignal          = signal;
         m_lastSignalBarTime   = bar1Time;
         
         PrintFormat("[SignalEngine] Initial breakout: %s at bar %s",
                     (signal == SIGNAL_BUY_BREAKOUT) ? "BUY" : "SELL",
                     TimeToString(bar1Time, TIME_DATE|TIME_MINUTES));
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Check for re-entry signal (touch from outside)                   |
   //| Both directions monitored simultaneously                         |
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE CheckReentry(double zoneHigh, double zoneLow)
   {
      // First check if price has gone outside the zone
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double tolerance = PipsToPrice(m_symbol, m_touchTolerancePips);
      double maxOvershoot = PipsToPrice(m_symbol, m_maxTouchOvershootPips);
      
      // Track if price goes outside zone
      if(ask > zoneHigh + tolerance && !m_priceWentOutside)
      {
         // Price went above zone
         if(ask > zoneHigh + tolerance + maxOvershoot)
            return SIGNAL_NONE;  // Too far outside
         m_priceWentOutside = true;
         m_outsideDirection = DIR_BUY;  // Price is above
      }
      else if(bid < zoneLow - tolerance && !m_priceWentOutside)
      {
         // Price went below zone
         if(bid < zoneLow - tolerance - maxOvershoot)
            return SIGNAL_NONE;  // Too far outside
         m_priceWentOutside = true;
         m_outsideDirection = DIR_SELL;  // Price is below
      }
      
      if(!m_priceWentOutside)
         return SIGNAL_NONE;
      
      // Now check if price returns to touch the zone boundary
      // If price was above and comes back to touch ZoneHigh → BUY
      // If price was below and comes back to touch ZoneLow → SELL
      ENUM_SIGNAL_TYPE signal = SIGNAL_NONE;
      
      if(m_outsideDirection == DIR_BUY)
      {
         // Price was above zone, now touching ZoneHigh → BUY signal
         if(bid <= zoneHigh + tolerance && bid >= zoneHigh - tolerance)
         {
            signal = SIGNAL_BUY_REENTRY;
         }
      }
      else if(m_outsideDirection == DIR_SELL)
      {
         // Price was below zone, now touching ZoneLow → SELL signal
         if(ask >= zoneLow - tolerance && ask <= zoneLow + tolerance)
         {
            signal = SIGNAL_SELL_REENTRY;
         }
      }
      
      if(signal != SIGNAL_NONE)
      {
         // Reset for next potential re-entry
         ResetReentry();
         m_lastSignal        = signal;
         m_lastSignalBarTime = TimeCurrent();
         
         PrintFormat("[SignalEngine] Re-entry signal: %s",
                     (signal == SIGNAL_BUY_REENTRY) ? "BUY" : "SELL");
      }
      
      return signal;
   }
   
   //+------------------------------------------------------------------+
   //| Reset re-entry state                                             |
   //+------------------------------------------------------------------+
   void ResetReentry()
   {
      m_priceWentOutside = false;
      m_outsideDirection = DIR_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new cycle                                              |
   //+------------------------------------------------------------------+
   void ResetForNewCycle()
   {
      m_initialBreakoutDone = false;
      m_lastSignal          = SIGNAL_NONE;
      m_lastSignalBarTime   = 0;
      ResetReentry();
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new day                                                |
   //+------------------------------------------------------------------+
   void ResetForNewDay()
   {
      ResetForNewCycle();
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsInitialBreakoutDone() const { return m_initialBreakoutDone; }
   ENUM_SIGNAL_TYPE GetLastSignal() const { return m_lastSignal; }
   
   //+------------------------------------------------------------------+
   //| Set state (for restoration)                                      |
   //+------------------------------------------------------------------+
   void SetInitialBreakoutDone(bool done) { m_initialBreakoutDone = done; }
   void SetPriceWentOutside(bool went) { m_priceWentOutside = went; }
   void SetOutsideDirection(ENUM_POSITION_DIRECTION dir) { m_outsideDirection = dir; }
};

#endif // SIGNAL_ENGINE_MQH
//+------------------------------------------------------------------+
