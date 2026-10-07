//+------------------------------------------------------------------+
//|                                          NewsCalendarExporter.mq5|
//|     Export historical economic calendar data to CSV file          |
//|     For use with ZoneRecoveryEA Strategy Tester backtesting       |
//+------------------------------------------------------------------+
#property copyright   "ZoneRecoveryEA"
#property version     "1.00"
#property description "Export historical high-impact news events to CSV"
#property description "Run this on a LIVE terminal before Strategy Tester"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input datetime         InpExportStartDate   = D'2024.01.01';    // Export Start Date
input datetime         InpExportEndDate     = D'2026.12.31';    // Export End Date
input string           InpExportCurrencies  = "USD,EUR,GBP,JPY,AUD,CAD,CHF,NZD"; // Export Currencies
input bool             InpExportHighImpactOnly = true;          // Export High Impact Only
input string           InpExportFilename    = "NewsCalendar.csv"; // Export Filename
input int              InpChunkDays         = 30;               // Export Chunk Size (days)

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
int    g_totalExported = 0;
int    g_totalEvents   = 0;
bool   g_exportSuccess = false;
string g_exportCurrencies[];
int    g_currencyCount;
datetime g_actualStartDate;
datetime g_actualEndDate;
string g_manifestChecksum;

//+------------------------------------------------------------------+
//| Script program start function                                      |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== NewsCalendarExporter v1.0 ===");
   PrintFormat("Export period: %s to %s", 
               TimeToString(InpExportStartDate, TIME_DATE),
               TimeToString(InpExportEndDate, TIME_DATE));
   
   // Parse currencies
   g_currencyCount = StringSplit(InpExportCurrencies, ',', g_exportCurrencies);
   for(int i = 0; i < g_currencyCount; i++)
   {
      StringTrimLeft(g_exportCurrencies[i]);
      StringTrimRight(g_exportCurrencies[i]);
      StringToUpper(g_exportCurrencies[i]);
   }
   
   PrintFormat("Currencies: %s (%d)", InpExportCurrencies, g_currencyCount);
   
   // Validate inputs
   if(InpExportStartDate >= InpExportEndDate)
   {
      Print("ERROR: Start date must be before end date");
      return;
   }
   
   // Try to check if Calendar API is available
   MqlCalendarValue values[];
   datetime testStart = InpExportStartDate;
   datetime testEnd   = testStart + 86400;  // 1 day
   
   if(!CalendarValueHistory(values, testStart, testEnd))
   {
      Print("WARNING: Calendar API returned error. Calendar data may not be available.");
      Print("This script requires internet connection and must be run on live terminal.");
      PrintFormat("Error code: %d", GetLastError());
   }
   
   // Export in chunks
   g_actualStartDate = InpExportStartDate;
   g_actualEndDate   = InpExportEndDate;
   
   bool success = ExportInChunks();
   
   if(success)
   {
      // Write manifest file
      WriteManifestFile();
      
      PrintFormat("=== EXPORT COMPLETED ===");
      PrintFormat("Total events found: %d", g_totalEvents);
      PrintFormat("Total values exported: %d", g_totalExported);
      PrintFormat("Output file: %s", InpExportFilename);
      g_exportSuccess = true;
   }
   else
   {
      Print("=== EXPORT FAILED ===");
      Print("CSV file may be incomplete. Do not use for backtesting.");
      g_exportSuccess = false;
   }
}

//+------------------------------------------------------------------+
//| Export calendar data in chunks                                    |
//+------------------------------------------------------------------+
bool ExportInChunks()
{
   // Open CSV file for writing (overwrite)
   int fileHandle = FileOpen(InpExportFilename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fileHandle == INVALID_HANDLE)
   {
      // Try without FILE_COMMON
      fileHandle = FileOpen(InpExportFilename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         PrintFormat("ERROR: Cannot create file: %s (Error: %d)", InpExportFilename, GetLastError());
         return false;
      }
   }
   
   // Write header
   FileWrite(fileHandle, 
             "EventID", "ValueID", "EventName", "Currency", "Importance",
             "OriginalEventTime", "BrokerServerTime", "BrokerDate", 
             "TimeMode", "ExportTimestamp", "Source", "DataStatus");
   
   // Export datetime for all rows
   string exportTimestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   
   // Process in chunks
   datetime chunkStart = InpExportStartDate;
   datetime chunkSize = InpChunkDays * 86400;
   bool allComplete = true;
   bool anyDataExported = false;
   
   while(chunkStart < InpExportEndDate)
   {
      datetime chunkEnd = chunkStart + chunkSize;
      if(chunkEnd > InpExportEndDate)
         chunkEnd = InpExportEndDate;
      
      PrintFormat("Exporting chunk: %s to %s", 
                  TimeToString(chunkStart, TIME_DATE),
                  TimeToString(chunkEnd, TIME_DATE));
      
      bool chunkResult = ExportChunk(fileHandle, chunkStart, chunkEnd, exportTimestamp);
      
      if(!chunkResult)
      {
         allComplete = false;
         PrintFormat("WARNING: Chunk %s to %s had incomplete data",
                     TimeToString(chunkStart, TIME_DATE),
                     TimeToString(chunkEnd, TIME_DATE));
      }
      else
      {
         anyDataExported = true;
      }
      
      // Progress
      int progress = (int)((chunkEnd - InpExportStartDate) * 100.0 / (InpExportEndDate - InpExportStartDate));
      PrintFormat("Progress: %d%%  Total exported: %d", progress, g_totalExported);
      
      chunkStart = chunkEnd;
      
      // Small delay to avoid overwhelming the API
      Sleep(100);
   }
   
   FileClose(fileHandle);
   
   return allComplete && anyDataExported;
}

//+------------------------------------------------------------------+
//| Export a single chunk of calendar data                            |
//+------------------------------------------------------------------+
bool ExportChunk(int fileHandle, datetime from, datetime to, string exportTimestamp)
{
   MqlCalendarValue values[];
   
   if(!CalendarValueHistory(values, from, to))
   {
      PrintFormat("CalendarValueHistory failed for %s to %s. Error: %d",
                  TimeToString(from, TIME_DATE), TimeToString(to, TIME_DATE),
                  GetLastError());
      return false;
   }
   
   int chunkExported = 0;
   
   for(int i = 0; i < ArraySize(values); i++)
   {
      // Get event details
      MqlCalendarEvent event;
      if(!CalendarEventById((int)values[i].event_id, event))
         continue;
      
      // Get country info
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;
      
      string currency = country.currency;
      StringToUpper(currency);
      
      // Check currency filter
      bool currencyMatch = false;
      for(int j = 0; j < g_currencyCount; j++)
      {
         if(g_exportCurrencies[j] == currency)
         {
            currencyMatch = true;
            break;
         }
      }
      if(!currencyMatch) continue;
      
      // Check importance filter
      if(InpExportHighImpactOnly && event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;
      
      g_totalEvents++;
      
      // Format importance string
      string importanceStr;
      switch(event.importance)
      {
         case CALENDAR_IMPORTANCE_LOW:      importanceStr = "LOW"; break;
         case CALENDAR_IMPORTANCE_MODERATE: importanceStr = "MODERATE"; break;
         case CALENDAR_IMPORTANCE_HIGH:     importanceStr = "HIGH"; break;
         default:                           importanceStr = "UNKNOWN"; break;
      }
      
      // Format time mode
      string timeModeStr;
      switch(event.time_mode)
      {
         case 0: timeModeStr = "UNSPECIFIED"; break;
         case 1: timeModeStr = "EXACT"; break;
         case 2: timeModeStr = "APPROXIMATE"; break;
         case 3: timeModeStr = "NO_TIME"; break;
         default: timeModeStr = "UNKNOWN"; break;
      }
      
      // Get actual event times
      datetime eventTime = values[i].time;
      string brokerDate  = TimeToString(eventTime, TIME_DATE);
      string brokerTime  = TimeToString(eventTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      
      // Write CSV row
      FileWrite(fileHandle,
                IntegerToString(values[i].event_id),
                IntegerToString((long)(values[i].id > 0 ? values[i].id : (ulong)i)),
                event.name,
                currency,
                importanceStr,
                brokerTime,           // OriginalEventTime
                brokerTime,           // BrokerServerTime
                brokerDate,           // BrokerDate
                timeModeStr,          // TimeMode
                exportTimestamp,      // ExportTimestamp
                "MT5_Calendar_API",   // Source
                "COMPLETE");          // DataStatus
      
      chunkExported++;
   }
   
   g_totalExported += chunkExported;
   PrintFormat("Chunk exported: %d values", chunkExported);
   
   return (chunkExported > 0 || ArraySize(values) > 0);
}

//+------------------------------------------------------------------+
//| Write manifest file                                               |
//+------------------------------------------------------------------+
void WriteManifestFile()
{
   string manifestFile = "NewsCalendar_manifest.txt";
   int fileHandle = FileOpen(manifestFile, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      fileHandle = FileOpen(manifestFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(fileHandle == INVALID_HANDLE)
      {
         PrintFormat("WARNING: Cannot create manifest file: %s", manifestFile);
         return;
      }
   }
   
   // Get broker info
   string brokerName = AccountInfoString(ACCOUNT_COMPANY);
   string serverName = AccountInfoString(ACCOUNT_SERVER);
   
   // Note: UTC offset cannot be determined programmatically from MT5 API alone.
   // All times in the export are in broker server timezone.
   
   // Calculate checksum (simple hash of the CSV)
   string checksum = CalculateFileChecksum();
   g_manifestChecksum = checksum;
   
   // Write manifest
   FileWriteString(fileHandle, "=== News Calendar Export Manifest ===\r\n");
   FileWriteString(fileHandle, "\r\n");
   FileWriteString(fileHandle, "ExportVersion: 1.0\r\n");
   FileWriteString(fileHandle, "ExportDate: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\r\n");
   FileWriteString(fileHandle, "StartDate: " + TimeToString(g_actualStartDate, TIME_DATE) + "\r\n");
   FileWriteString(fileHandle, "EndDate: " + TimeToString(g_actualEndDate, TIME_DATE) + "\r\n");
   FileWriteString(fileHandle, "Currencies: " + InpExportCurrencies + "\r\n");
   FileWriteString(fileHandle, "HighImpactOnly: " + (InpExportHighImpactOnly ? "true" : "false") + "\r\n");
   FileWriteString(fileHandle, "\r\n");
   FileWriteString(fileHandle, "=== Broker Info ===\r\n");
   FileWriteString(fileHandle, "Broker: " + brokerName + "\r\n");
   FileWriteString(fileHandle, "Server: " + serverName + "\r\n");
   FileWriteString(fileHandle, "ServerTime: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "\r\n");
   FileWriteString(fileHandle, "TimezoneOffset: Server time (broker-specific)\r\n");
   FileWriteString(fileHandle, "\r\n");
   FileWriteString(fileHandle, "=== Data Summary ===\r\n");
   FileWriteString(fileHandle, "TotalEvents: " + IntegerToString(g_totalEvents) + "\r\n");
   FileWriteString(fileHandle, "TotalValues: " + IntegerToString(g_totalExported) + "\r\n");
   FileWriteString(fileHandle, "CSVFile: " + InpExportFilename + "\r\n");
   FileWriteString(fileHandle, "DataStatus: " + (g_exportSuccess ? "COMPLETE" : "INCOMPLETE") + "\r\n");
   FileWriteString(fileHandle, "\r\n");
   FileWriteString(fileHandle, "=== Integrity ===\r\n");
   FileWriteString(fileHandle, "Checksum: " + checksum + "\r\n");
   FileWriteString(fileHandle, "Verification: " + (g_exportSuccess ? "PASS" : "FAIL") + "\r\n");
   FileWriteString(fileHandle, "\r\n");
   FileWriteString(fileHandle, "=== Notes ===\r\n");
   FileWriteString(fileHandle, "- All times are in broker server timezone\r\n");
   FileWriteString(fileHandle, "- DST transitions are handled by broker server\r\n");
   FileWriteString(fileHandle, "- Calendar data may be revised by providers after export\r\n");
   FileWriteString(fileHandle, "- This export version is locked in the checksum\r\n");
   
   FileClose(fileHandle);
   
   PrintFormat("Manifest written: %s (Checksum: %s)", manifestFile, checksum);
}

//+------------------------------------------------------------------+
//| Calculate simple file checksum                                    |
//+------------------------------------------------------------------+
string CalculateFileChecksum()
{
   int fileHandle = FileOpen(InpExportFilename, FILE_READ|FILE_BIN|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      fileHandle = FileOpen(InpExportFilename, FILE_READ|FILE_BIN);
      if(fileHandle == INVALID_HANDLE)
         return "UNKNOWN";
   }
   
   uint hash = 0;
   uchar buffer[];
   uint bytesRead;
   
   while(!FileIsEnding(fileHandle))
   {
      bytesRead = FileReadArray(fileHandle, buffer, 0, 4096);
      if(bytesRead == 0) break;
      
      for(uint i = 0; i < bytesRead; i++)
      {
         hash ^= (uint)buffer[i];
         for(int j = 0; j < 8; j++)
         {
         if((hash & 1) != 0)
               hash = (hash >> 1) ^ 0xEDB88320;
            else
               hash >>= 1;
         }
      }
   }
   
   FileClose(fileHandle);
   
   return IntegerToString((ulong)hash, 16, '0');
}
//+------------------------------------------------------------------+
