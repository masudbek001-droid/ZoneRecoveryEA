//+------------------------------------------------------------------+
//|                                                  NewsFilter.mqh  |
//|        Economic news filter - blocks trading on high-impact days  |
//+------------------------------------------------------------------+
#ifndef NEWS_FILTER_MQH
#define NEWS_FILTER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CNewsFilter class                                                 |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   string           m_symbol;
   bool             m_enabled;
   string           m_currencies;        // Comma-separated currencies
   string           m_csvFilePath;
   
   // Blocked days cache
   datetime         m_blockedDays[];     // Array of blocked day start times
   int              m_blockedDaysCount;
   int              m_todayNewsCount;
   bool             m_todayIsBlocked;
   datetime         m_nextBlockedDate;
   string           m_todayEvents;
   string           m_nextEventName;
   bool             m_csvLoaded;
   string           m_dataStatus;        // "OK", "MISSING", "INCOMPLETE", "OFFLINE"
   
   //+------------------------------------------------------------------+
   //| Get related currencies from symbol                               |
   //+------------------------------------------------------------------+
   string DetectCurrencies(string symbol)
   {
      string base  = GetBaseCurrency(symbol);
      string quote = GetQuoteCurrency(symbol);
      return base + "," + quote;
   }
   
   //+------------------------------------------------------------------+
   //| Parse CSV file and populate blocked days                         |
   //+------------------------------------------------------------------+
   bool LoadCSVFile()
   {
      m_blockedDaysCount = 0;
      ArrayResize(m_blockedDays, 0);
      
      int fileHandle = FileOpen(m_csvFilePath, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         // Try without FILE_COMMON
         fileHandle = FileOpen(m_csvFilePath, FILE_READ|FILE_CSV|FILE_ANSI, ',');
         if(fileHandle == INVALID_HANDLE)
         {
            m_dataStatus = "MISSING";
            PrintFormat("[NewsFilter] CSV file not found: %s", m_csvFilePath);
            return false;
         }
      }
      
      // Skip header line - read all fields until end of line
      if(!FileIsEnding(fileHandle))
      {
         // Read and discard header fields
         string headerField = "";
         int headerFieldsRead = 0;
         while(!FileIsLineEnding(fileHandle) && !FileIsEnding(fileHandle))
         {
            headerField = FileReadString(fileHandle);
            headerFieldsRead++;
            if(headerFieldsRead > 20) break;  // Safety limit
         }
         // If we stopped at a line ending (not file end), the FileReadString
         // in the next iteration will start on the data line
      }
      
      // Read data rows
      datetime lastBlockedDay = 0;
      datetime now = TimeCurrent();
      datetime today = GetDayStart(now);
      
      while(!FileIsEnding(fileHandle))
      {
         // Read columns
         string eventID      = FileReadString(fileHandle);
         string valueID      = FileReadString(fileHandle);
         string eventName    = FileReadString(fileHandle);
         string currency     = FileReadString(fileHandle);
         string importance   = FileReadString(fileHandle);
         string eventTimeStr = FileReadString(fileHandle);
         string brokerTime   = FileReadString(fileHandle);
         string brokerDate   = FileReadString(fileHandle);
         string timeMode     = FileReadString(fileHandle);
         string exportTS     = FileReadString(fileHandle);
         string source       = FileReadString(fileHandle);
         string dataStatus   = FileReadString(fileHandle);
         
         // Skip to next line if there are remaining fields
         while(!FileIsLineEnding(fileHandle) && !FileIsEnding(fileHandle))
            FileReadString(fileHandle);
         
         if(currency == "") continue;
         
         StringToUpper(currency);
         StringToUpper(importance);
         
         // Check if this is high impact and related currency
         if(importance != "HIGH" && importance != "3" && importance != "***")
            continue;
         
         // Check currency match
         bool currencyMatch = false;
         string curList[];
         int curCount = StringSplit(m_currencies, ',', curList);
         for(int i = 0; i < curCount; i++)
         {
            string c = curList[i];
            StringTrimLeft(c);
            StringTrimRight(c);
            StringToUpper(c);
            if(c == currency)
            {
               currencyMatch = true;
               break;
            }
         }
         
         if(!currencyMatch) continue;
         
         // Parse event time
         datetime eventTime = StringToTime(brokerDate);
         if(eventTime == 0)
            eventTime = StringToTime(brokerTime);
         if(eventTime == 0)
            eventTime = StringToTime(eventTimeStr);
         
         if(eventTime == 0) continue;
         
         datetime dayStart = GetDayStart(eventTime);
         
         // Add to blocked days (avoid duplicates)
         bool alreadyAdded = false;
         for(int i = 0; i < m_blockedDaysCount; i++)
         {
            if(m_blockedDays[i] == dayStart)
            {
               alreadyAdded = true;
               break;
            }
         }
         
         if(!alreadyAdded)
         {
            m_blockedDaysCount++;
            ArrayResize(m_blockedDays, m_blockedDaysCount);
            m_blockedDays[m_blockedDaysCount - 1] = dayStart;
         }
      }
      
      FileClose(fileHandle);
      
      // Sort blocked days
      ArraySort(m_blockedDays);
      
      // Find next blocked date after today
      m_nextBlockedDate = 0;
      for(int i = 0; i < m_blockedDaysCount; i++)
      {
         if(m_blockedDays[i] > today)
         {
            m_nextBlockedDate = m_blockedDays[i];
            break;
         }
      }
      
      m_csvLoaded = true;
      m_dataStatus = "OK";
      
      PrintFormat("[NewsFilter] Loaded %d blocked days from CSV", m_blockedDaysCount);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check today using MQL5 Calendar API (online mode)                |
   //+------------------------------------------------------------------+
   bool CheckTodayOnline()
   {
      datetime now = TimeCurrent();
      datetime todayStart = GetDayStart(now);
      datetime todayEnd   = GetDayEnd(now);
      
      // Get calendar values for today
      MqlCalendarValue values[];
      if(!CalendarValueHistory(values, todayStart, todayEnd))
      {
         m_dataStatus = "OFFLINE";
         return false;
      }
      
      m_todayNewsCount = 0;
      m_todayEvents    = "";
      
      for(int i = 0; i < ArraySize(values); i++)
      {
         // Get event details
         MqlCalendarEvent event;
         if(!CalendarEventById((int)values[i].event_id, event))
            continue;
         
         // Check importance
         if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;
         
         // Get event country/currency
         MqlCalendarCountry country;
         if(!CalendarCountryById(event.country_id, country))
            continue;
         
         string currency = country.currency;
         StringToUpper(currency);
         
         // Check if this currency is related
         string curList[];
         int curCount = StringSplit(m_currencies, ',', curList);
         bool match = false;
         for(int j = 0; j < curCount; j++)
         {
            string c = curList[j];
            StringTrimLeft(c);
            StringTrimRight(c);
            StringToUpper(c);
            if(c == currency)
            {
               match = true;
               break;
            }
         }
         
         if(!match) continue;
         
         m_todayNewsCount++;
         
         // Get event name
         MqlCalendarEvent ev;
         if(CalendarEventById((int)values[i].event_id, ev))
         {
            if(m_todayEvents != "") m_todayEvents += ", ";
            m_todayEvents += ev.name;
         }
      }
      
      m_todayIsBlocked = (m_todayNewsCount > 0);
      
      if(m_todayIsBlocked)
      {
         PrintFormat("[NewsFilter] Today BLOCKED: %d high-impact events: %s",
                     m_todayNewsCount, m_todayEvents);
      }
      else
      {
         Print("[NewsFilter] Today OK - no high-impact news for related currencies");
      }
      
      return m_todayIsBlocked;
   }

public:
   CNewsFilter()
   {
      m_enabled          = false;
      m_todayIsBlocked   = false;
      m_todayNewsCount   = 0;
      m_csvLoaded        = false;
      m_dataStatus       = "NOT_INITIALIZED";
      m_nextBlockedDate  = 0;
      m_blockedDaysCount = 0;
   }
   
   void Init(string symbol, bool enabled, string currencies = "")
   {
      m_symbol  = symbol;
      m_enabled = enabled;
      
      if(currencies != "")
         m_currencies = currencies;
      else
         m_currencies = DetectCurrencies(symbol);
      
      m_csvFilePath = ZRE_NEWS_CSV_FILE;
   }
   
   //+------------------------------------------------------------------+
   //| Update news status - call at start of each day                   |
   //+------------------------------------------------------------------+
   bool Update()
   {
      if(!m_enabled)
      {
         m_todayIsBlocked = false;
         m_dataStatus = "DISABLED";
         return false;
      }
      
      // First try CSV
      if(!m_csvLoaded)
      {
         LoadCSVFile();
      }
      
      // Check if today is in blocked days list
      datetime now = TimeCurrent();
      datetime today = GetDayStart(now);
      
      m_todayIsBlocked = false;
      m_todayNewsCount = 0;
      
      for(int i = 0; i < m_blockedDaysCount; i++)
      {
         if(m_blockedDays[i] == today)
         {
            m_todayIsBlocked = true;
            m_todayNewsCount = 1;
            m_todayEvents = "From CSV";
            break;
         }
      }
      
      // If CSV doesn't have today, try online API
      if(!m_todayIsBlocked && !IsTester())
      {
         CheckTodayOnline();
      }
      
      return m_todayIsBlocked;
   }
   
   //+------------------------------------------------------------------+
   //| Check if today is a blocked news day                             |
   //+------------------------------------------------------------------+
   bool IsTodayBlocked() const { return m_todayIsBlocked; }
   
   //+------------------------------------------------------------------+
   //| Check if news filter is enabled                                  |
   //+------------------------------------------------------------------+
   bool IsEnabled() const { return m_enabled; }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   string GetCurrencies() const { return m_currencies; }
   int GetTodayNewsCount() const { return m_todayNewsCount; }
   string GetTodayEvents() const { return m_todayEvents; }
   datetime GetNextBlockedDate() const { return m_nextBlockedDate; }
   string GetDataStatus() const { return m_dataStatus; }
   string GetNextEventName() const { return m_nextEventName; }
   
   //+------------------------------------------------------------------+
   //| Check if running in tester                                       |
   //+------------------------------------------------------------------+
   bool IsTester()
   {
      return (bool)MQLInfoInteger(MQL_TESTER);
   }
   
   //+------------------------------------------------------------------+
   //| Force CSV reload                                                 |
   //+------------------------------------------------------------------+
   void ReloadCSV()
   {
      m_csvLoaded = false;
      m_blockedDaysCount = 0;
      ArrayResize(m_blockedDays, 0);
      LoadCSVFile();
   }
   
   //+------------------------------------------------------------------+
   //| Set blocked status manually (for forced news days)               |
   //+------------------------------------------------------------------+
   void SetTodayBlocked(bool blocked, string events = "Manual override")
   {
      m_todayIsBlocked = blocked;
      if(blocked) m_todayEvents = events;
   }
};

#endif // NEWS_FILTER_MQH
//+------------------------------------------------------------------+
