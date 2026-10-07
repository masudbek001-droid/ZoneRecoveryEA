//+------------------------------------------------------------------+
//|                                                  ZoneManager.mqh |
//|              Zone identification, formation, and management       |
//+------------------------------------------------------------------+
#ifndef ZONE_MANAGER_MQH
#define ZONE_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CZoneManager class                                                |
//+------------------------------------------------------------------+
class CZoneManager
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_zoneTimeframe;
   int              m_zoneHour;
   int              m_zoneMinute;
   ZoneData         m_currentZone;
   bool             m_zoneFormed;
   ulong            m_zoneCounter;
   
   // Previous zone for display
   ZoneData         m_previousZone;

   //+------------------------------------------------------------------+
   //| Find the specific candle that forms the zone                     |
   //+------------------------------------------------------------------+
   bool FindZoneCandle(datetime &candleOpenTime, datetime &candleCloseTime, 
                        double &high, double &low)
   {
      // We need to find the candle on m_zoneTimeframe that opens at 
      // the specified hour:minute (broker time)
      datetime now = TimeCurrent();
      MqlDateTime nowDT;
      TimeToStruct(now, nowDT);
      
      // Build the target datetime for today at zone hour:minute
      MqlDateTime targetDT;
      targetDT.year = nowDT.year;
      targetDT.mon  = nowDT.mon;
      targetDT.day  = nowDT.day;
      targetDT.hour = m_zoneHour;
      targetDT.min  = m_zoneMinute;
      targetDT.sec  = 0;
      datetime targetTime = StructToTime(targetDT);
      
      // Get bars for the zone timeframe
      int bars = iBars(m_symbol, m_zoneTimeframe);
      if(bars < 2) return false;
      
      // Scan through bars to find the one that opens at target time
      // We check bars from most recent going backwards
      for(int i = 0; i < MathMin(bars, 50); i++)
      {
         datetime barTime = iTime(m_symbol, m_zoneTimeframe, i);
         if(barTime == 0) continue;
         
         if(barTime == targetTime)
         {
            // Found the candle
            // Check if it's fully closed (i > 0 means current bar is different)
            if(i == 0) 
            {
               // Current bar is the zone candle but not yet closed
               return false;
            }
            
            candleOpenTime  = barTime;
            candleCloseTime = iTime(m_symbol, m_zoneTimeframe, i - 1);
            high = iHigh(m_symbol, m_zoneTimeframe, i);
            low  = iLow(m_symbol, m_zoneTimeframe, i);
            return true;
         }
      }
      
      // Also check if target time has passed and the candle has closed
      // If targetTime < now and we haven't found it, check if it exists
      if(targetTime <= now)
      {
         // The target time has passed but candle might not exist (weekend, etc.)
         // Try to find the nearest candle that was open during target time
         for(int i = 1; i < MathMin(bars, 50); i++)
         {
            datetime barOpen  = iTime(m_symbol, m_zoneTimeframe, i);
            datetime barClose = iTime(m_symbol, m_zoneTimeframe, i - 1);
            
            if(barOpen <= targetTime && barClose > targetTime)
            {
               // This candle was active during target time
               // Use this candle
               candleOpenTime  = barOpen;
               candleCloseTime = barClose;
               high = iHigh(m_symbol, m_zoneTimeframe, i);
               low  = iLow(m_symbol, m_zoneTimeframe, i);
               return true;
            }
         }
      }
      
      return false;
   }

public:
   CZoneManager() 
   {
      m_zoneFormed   = false;
      m_zoneCounter  = 0;
      ZeroMemory(m_currentZone);
      ZeroMemory(m_previousZone);
   }
   
   void Init(string symbol, ENUM_TIMEFRAMES zoneTimeframe, int zoneHour, int zoneMinute)
   {
      m_symbol         = symbol;
      m_zoneTimeframe  = zoneTimeframe;
      m_zoneHour       = zoneHour;
      m_zoneMinute     = zoneMinute;
      m_zoneFormed     = false;
      m_zoneCounter    = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Update zone status - call every tick/timer                       |
   //+------------------------------------------------------------------+
   bool Update()
   {
      if(m_zoneFormed) return true;  // Zone already formed for today
      
      // Try to find the zone candle
      datetime candleOpen, candleClose;
      double high, low;
      
      if(!FindZoneCandle(candleOpen, candleClose, high, low))
         return false;
      
      // Validate zone
      if(high <= low) return false;
      
      // Form the zone
      m_zoneCounter++;
      m_currentZone.ZoneID          = m_zoneCounter;
      m_currentZone.ZoneHigh        = high;
      m_currentZone.ZoneLow         = low;
      m_currentZone.ZoneSize        = high - low;
      m_currentZone.ZonePips        = PriceToPips(m_symbol, m_currentZone.ZoneSize);
      m_currentZone.ZoneTime        = candleOpen;
      m_currentZone.ZoneActiveFrom  = candleClose;
      m_currentZone.ZoneTimeframe   = m_zoneTimeframe;
      m_currentZone.IsValid         = true;
      
      m_zoneFormed = true;
      
      PrintFormat("[ZoneManager] Zone formed: High=%.5f Low=%.5f Size=%.5f (%.1f pips) Time=%s",
                  high, low, m_currentZone.ZoneSize, m_currentZone.ZonePips,
                  TimeToString(candleOpen, TIME_DATE|TIME_MINUTES));
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Reset for a new day                                              |
   //+------------------------------------------------------------------+
   void Reset()
   {
      if(m_zoneFormed)
      {
         m_previousZone = m_currentZone;
      }
      m_zoneFormed = false;
      ZeroMemory(m_currentZone);
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   bool IsZoneFormed() const { return m_zoneFormed; }
   
   const ZoneData& GetZone() const { return m_currentZone; }
   
   double GetZoneHigh() const { return m_currentZone.ZoneHigh; }
   double GetZoneLow() const  { return m_currentZone.ZoneLow; }
   double GetZoneSize() const { return m_currentZone.ZoneSize; }
   double GetZonePips() const { return m_currentZone.ZonePips; }
   ulong  GetZoneID() const   { return m_currentZone.ZoneID; }
   datetime GetZoneTime() const { return m_currentZone.ZoneTime; }
   
   const ZoneData& GetPreviousZone() const { return m_previousZone; }
   bool HasPreviousZone() const { return m_previousZone.IsValid; }
   
   ENUM_TIMEFRAMES GetTimeframe() const { return m_zoneTimeframe; }
   
   //+------------------------------------------------------------------+
   //| Set zone manually (for state restoration)                        |
   //+------------------------------------------------------------------+
   void SetZone(const ZoneData &zone)
   {
      m_currentZone = zone;
      m_zoneFormed = zone.IsValid;
      if(zone.ZoneID > m_zoneCounter)
         m_zoneCounter = zone.ZoneID;
   }
};

#endif // ZONE_MANAGER_MQH
//+------------------------------------------------------------------+
