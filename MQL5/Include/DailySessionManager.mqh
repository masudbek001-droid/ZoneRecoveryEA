//+------------------------------------------------------------------+
//|                                           DailySessionManager.mqh|
//|            Daily session management and forced close              |
//+------------------------------------------------------------------+
#ifndef DAILY_SESSION_MANAGER_MQH
#define DAILY_SESSION_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CDailySessionManager class                                        |
//+------------------------------------------------------------------+
class CDailySessionManager
{
private:
   string           m_symbol;
   int              m_closeHour;
   int              m_closeMinute;
   datetime         m_todayCloseTime;
   datetime         m_lastCheckDay;
   bool             m_closeTimeReached;
   bool             m_isWeekend;
   
   //+------------------------------------------------------------------+
   //| Calculate close time for today                                   |
   //+------------------------------------------------------------------+
   datetime CalculateCloseTime()
   {
      datetime now = TimeCurrent();
      MqlDateTime mdt;
      TimeToStruct(now, mdt);
      
      mdt.hour = m_closeHour;
      mdt.min  = m_closeMinute;
      mdt.sec  = 0;
      
      return StructToTime(mdt);
   }
   
   //+------------------------------------------------------------------+
   //| Check if today is a trading day (not weekend)                    |
   //+------------------------------------------------------------------+
   bool IsTradingDay()
   {
      datetime now = TimeCurrent();
      int dow = TimeDayOfWeek(now);
      return (dow >= 1 && dow <= 5);  // Monday to Friday
   }

public:
   CDailySessionManager()
   {
      m_todayCloseTime  = 0;
      m_lastCheckDay    = 0;
      m_closeTimeReached = false;
      m_isWeekend        = false;
   }
   
   void Init(string symbol, int closeHour, int closeMinute)
   {
      m_symbol      = symbol;
      m_closeHour   = closeHour;
      m_closeMinute = closeMinute;
      Update();
   }
   
   //+------------------------------------------------------------------+
   //| Update session status - call every tick/timer                    |
   //+------------------------------------------------------------------+
   void Update()
   {
      datetime now = TimeCurrent();
      
      // Check if day has changed
      datetime today = GetDayStart(now);
      if(today != m_lastCheckDay)
      {
         m_lastCheckDay    = today;
         m_todayCloseTime  = CalculateCloseTime();
         m_closeTimeReached = false;
         m_isWeekend = !IsTradingDay();
         
         PrintFormat("[DailySession] New day: CloseTime=%s Weekend=%s",
                     TimeToString(m_todayCloseTime, TIME_DATE|TIME_MINUTES),
                     m_isWeekend ? "YES" : "NO");
      }
      
      // Check if close time has been reached
      if(!m_closeTimeReached && now >= m_todayCloseTime)
      {
         m_closeTimeReached = true;
         PrintFormat("[DailySession] Close time reached at %s", 
                     TimeToString(now, TIME_MINUTES));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if close time has been reached                             |
   //+------------------------------------------------------------------+
   bool IsCloseTimeReached() const
   {
      return m_closeTimeReached;
   }
   
   //+------------------------------------------------------------------+
   //| Check if we are in the active trading window                     |
   //| (after zone candle closed but before close time)                 |
   //+------------------------------------------------------------------+
   bool IsInTradingWindow(datetime zoneActiveFrom)
   {
      if(m_isWeekend) return false;
      if(m_closeTimeReached) return false;
      
      datetime now = TimeCurrent();
      return (now >= zoneActiveFrom && now < m_todayCloseTime);
   }
   
   //+------------------------------------------------------------------+
   //| Get remaining trading time in seconds                            |
   //+------------------------------------------------------------------+
   int GetRemainingTime()
   {
      if(m_closeTimeReached) return 0;
      
      datetime now = TimeCurrent();
      if(now >= m_todayCloseTime) return 0;
      
      return (int)(m_todayCloseTime - now);
   }
   
   //+------------------------------------------------------------------+
   //| Format remaining time as HH:MM:SS                                |
   //+------------------------------------------------------------------+
   string GetRemainingTimeString()
   {
      int remaining = GetRemainingTime();
      if(remaining <= 0) return "00:00:00";
      
      int hours   = remaining / 3600;
      int minutes = (remaining % 3600) / 60;
      int seconds = remaining % 60;
      
      return StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   datetime GetCloseTime() const { return m_todayCloseTime; }
   bool IsWeekend() const { return m_isWeekend; }
   int GetCloseHour() const { return m_closeHour; }
   int GetCloseMinute() const { return m_closeMinute; }
   ENUM_DAY_STATUS GetDayStatus()
   {
      if(m_closeTimeReached) return DAY_STATUS_CLOSED;
      if(m_isWeekend) return DAY_STATUS_CLOSED;
      return DAY_STATUS_ACTIVE;
   }
   
   //+------------------------------------------------------------------+
   //| Reset for new day                                                |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_closeTimeReached = false;
      m_lastCheckDay = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Set close time parameters                                        |
   //+------------------------------------------------------------------+
   void SetCloseTime(int hour, int minute)
   {
      m_closeHour   = hour;
      m_closeMinute = minute;
      m_lastCheckDay = 0;  // Force recalculation
   }
};

#endif // DAILY_SESSION_MANAGER_MQH
//+------------------------------------------------------------------+
