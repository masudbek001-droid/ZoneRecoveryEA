//+------------------------------------------------------------------+
//|                                                CommonDefines.mqh |
//|                        ZoneRecoveryEA - Common Constants & Enums  |
//+------------------------------------------------------------------+
#ifndef COMMON_DEFINES_MQH
#define COMMON_DEFINES_MQH

//--- Version
#define ZRE_VERSION "1.0.0"
#define ZRE_BUILD   "2026.10"

//--- Magic Number default
#define ZRE_DEFAULT_MAGIC 218608

//--- Pip constants
#define PIP_MULTIPLIER_5DIGIT  10.0      // For 5-digit brokers (e.g. 1.23456)
#define PIP_MULTIPLIER_3DIGIT  1000.0    // For JPY pairs (e.g. 123.456)

//--- Time constants
#define SECONDS_PER_MINUTE 60
#define SECONDS_PER_HOUR   3600
#define SECONDS_PER_DAY    86400

//--- State file name
#define ZRE_STATE_FILE       "ZoneRecoveryEA_State.bin"
#define ZRE_TRADE_LOG_FILE   "ZoneRecoveryEA_Trades.csv"
#define ZRE_CYCLE_LOG_FILE   "ZoneRecoveryEA_Cycles.csv"
#define ZRE_NEWS_CSV_FILE    "NewsCalendar.csv"
#define ZRE_NEWS_MANIFEST    "NewsCalendar_manifest.txt"

//--- GV prefix for position lock
#define ZRE_GV_LOCK_PREFIX   "ZRE_LOCK_"
#define ZRE_GV_POSITION_KEY  "ZRE_POSITION_"

//--- Maximum cycle trades safety limit
#define MAX_CYCLE_TRADES_HARD_LIMIT 50

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_ZONE_STATE
{
   STATE_WAIT_ZONE = 0,            // Waiting for zone candle to form
   STATE_WAIT_INITIAL_BREAKOUT,    // Zone formed, waiting for first breakout
   STATE_IN_POSITION,              // Position is open, monitoring TP/SL
   STATE_SL_CLOSE_PENDING,        // SL signal detected, waiting for close confirm
   STATE_REVERSAL_PENDING,        // After SL, preparing reversal trade
   STATE_WAIT_REENTRY,            // After TP, waiting for re-entry touch
   STATE_NEWS_BLOCKED_DAY,        // News day - no trading
   STATE_NEWS_FORCED_CLOSE,       // News day - forcing close of open positions
   STATE_DAY_END_CLOSE,           // Day end - forcing close
   STATE_DAY_COMPLETED,           // Day session completed
   STATE_RISK_HALT,               // Risk limits breached - halt trading
   STATE_RECOVERY_REQUIRED        // Recovery mode active
};

enum ENUM_BREAKOUT_MODE
{
   BREAKOUT_MODE_NONE = 0,         // No distance filter
   BREAKOUT_MODE_PERCENT,          // Max distance as % of zone size
   BREAKOUT_MODE_FIXED_PIPS        // Max distance in fixed pips
};

enum ENUM_CYCLE_PROFIT_MODE
{
   CYCLE_PROFIT_FIXED = 0,         // Fixed profit target with recovery
   CYCLE_PROFIT_RECOVERY_ONLY      // Recovery only, no extra profit after Nth trade
};

enum ENUM_POSITION_DIRECTION
{
   DIR_NONE = 0,
   DIR_BUY = 1,
   DIR_SELL = 2
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY_BREAKOUT,
   SIGNAL_SELL_BREAKOUT,
   SIGNAL_BUY_REENTRY,
   SIGNAL_SELL_REENTRY,
   SIGNAL_BUY_REVERSAL,
   SIGNAL_SELL_REVERSAL
};

enum ENUM_DAY_STATUS
{
   DAY_STATUS_ACTIVE = 0,
   DAY_STATUS_NEWS_BLOCKED,
   DAY_STATUS_CLOSED,
   DAY_STATUS_COMPLETED,
   DAY_STATUS_RISK_HALTED
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct ZoneData
{
   ulong            ZoneID;
   double           ZoneHigh;
   double           ZoneLow;
   double           ZoneSize;
   double           ZonePips;
   datetime         ZoneTime;           // Time of the zone candle
   datetime         ZoneActiveFrom;     // When zone becomes active
   ENUM_TIMEFRAMES  ZoneTimeframe;
   bool             IsValid;
};

struct CycleData
{
   ulong            CycleID;
   int              TradeNumber;         // 1-based trade number in cycle
   double           CurrentLot;
   double           TotalCyclePnL;
   double           UnrecoveredLoss;
   ulong            PositionIdentifier;
   ENUM_POSITION_DIRECTION PositionDir;
   double           EntryPrice;
   double           TPPrice;
   bool             IsActive;
};

struct NewsDayInfo
{
   datetime         DayDate;            // Date of the news day
   int              EventCount;         // Number of high-impact events
   bool             IsBlocked;          // Whether trading is blocked
   string           EventNames;         // Comma-separated event names
};

struct TradeRecord
{
   ulong            TradeID;
   ulong            CycleID;
   ulong            ZoneID;
   int              TradeNumber;
   ENUM_POSITION_DIRECTION Direction;
   double           Lot;
   double           EntryPrice;
   double           ExitPrice;
   double           TPPrice;
   double           PnL;
   string           CloseReason;        // "TP", "SL", "REVERSAL", "DAY_END", "NEWS_CLOSE", "RISK_HALT"
   datetime         OpenTime;
   datetime         CloseTime;
};

struct SessionData
{
   datetime         ZoneCandleOpenTime;
   datetime         ZoneCandleCloseTime;
   datetime         DailyCloseTime;
   int              ZoneHour;
   int              ZoneMinute;
   int              CloseHour;
   int              CloseMinute;
};

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate pip size for the current symbol                        |
//+------------------------------------------------------------------+
double GetPipSize(string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(digits == 3 || digits == 5)
      return point * 10;  // JPY pairs and 5-digit brokers
   else
      return point * 10;  // Standard: 0.0001 for 4-digit, 0.01 for 2-digit
}

//+------------------------------------------------------------------+
//| Calculate pip size for XAUUSD and similar metals                 |
//+------------------------------------------------------------------+
double GetPipSizeForSymbol(string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Check if it's a metal/CFD
   string upperSymbol = symbol;
   StringToUpper(upperSymbol);
   
   if(StringFind(upperSymbol, "XAU") >= 0 || StringFind(upperSymbol, "GOLD") >= 0)
      return point * 10;  // Gold: 0.1 pip = 1.0 point typically
   
   if(StringFind(upperSymbol, "XAG") >= 0 || StringFind(upperSymbol, "SILVER") >= 0)
      return point * 10;
   
   // Standard forex
   if(digits == 3 || digits == 5)
      return point * 10;
   else if(digits == 2)
      return point * 10;
   else
      return point * 10;  // Default
}

//+------------------------------------------------------------------+
//| Convert pips to price                                            |
//+------------------------------------------------------------------+
double PipsToPrice(string symbol, double pips)
{
   double pipSize = GetPipSizeForSymbol(symbol);
   return pips * pipSize;
}

//+------------------------------------------------------------------+
//| Convert price distance to pips                                   |
//+------------------------------------------------------------------+
double PriceToPips(string symbol, double priceDistance)
{
   double pipSize = GetPipSizeForSymbol(symbol);
   if(pipSize == 0) return 0;
   return priceDistance / pipSize;
}

//+------------------------------------------------------------------+
//| Get point size for symbol                                        |
//+------------------------------------------------------------------+
double GetPointSize(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get volume step for symbol                                       |
//+------------------------------------------------------------------+
double GetVolumeStep(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
}

//+------------------------------------------------------------------+
//| Normalize lot to broker requirements                             |
//+------------------------------------------------------------------+
double NormalizeLot(string symbol, double lot)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(lotStep <= 0) lotStep = 0.01;
   
   // Round down to nearest lot step
   lot = MathFloor(lot / lotStep) * lotStep;
   
   // Clamp to min/max
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   // Normalize
   lot = NormalizeDouble(lot, 2);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Get contract size for symbol                                     |
//+------------------------------------------------------------------+
double GetContractSize(string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
}

//+------------------------------------------------------------------+
//| Extract base currency from symbol                                |
//+------------------------------------------------------------------+
string GetBaseCurrency(string symbol)
{
   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   StringToUpper(base);
   return base;
}

//+------------------------------------------------------------------+
//| Extract quote currency from symbol                               |
//+------------------------------------------------------------------+
string GetQuoteCurrency(string symbol)
{
   string quote = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   StringToUpper(quote);
   return quote;
}

//+------------------------------------------------------------------+
//| Get all related currencies for a symbol                          |
//+------------------------------------------------------------------+
string GetRelatedCurrencies(string symbol)
{
   string base  = GetBaseCurrency(symbol);
   string quote = GetQuoteCurrency(symbol);
   return base + "," + quote;
}

//+------------------------------------------------------------------+
//| Check if date1 and date2 are the same calendar day (broker time) |
//+------------------------------------------------------------------+
bool IsSameDay(datetime date1, datetime date2)
{
   MqlDateTime dt1, dt2;
   TimeToStruct(date1, dt1);
   TimeToStruct(date2, dt2);
   return (dt1.year == dt2.year && dt1.mon == dt2.mon && dt1.day == dt2.day);
}

//+------------------------------------------------------------------+
//| Get start of day (broker time)                                   |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime dt)
{
   MqlDateTime mdt;
   TimeToStruct(dt, mdt);
   mdt.hour = 0;
   mdt.min  = 0;
   mdt.sec  = 0;
   return StructToTime(mdt);
}

//+------------------------------------------------------------------+
//| Get end of day (broker time)                                     |
//+------------------------------------------------------------------+
datetime GetDayEnd(datetime dt)
{
   return GetDayStart(dt) + SECONDS_PER_DAY - 1;
}

//+------------------------------------------------------------------+
//| Get next day start (broker time)                                 |
//+------------------------------------------------------------------+
datetime GetNextDayStart(datetime dt)
{
   return GetDayStart(dt) + SECONDS_PER_DAY;
}

//+------------------------------------------------------------------+
//| Check if market is open                                          |
//+------------------------------------------------------------------+
bool IsMarketOpen(string symbol)
{
   datetime now = TimeCurrent();
   int dayOfWeek = TimeDayOfWeek(now);
   
   // Try to find any trade session for today
   // There may be multiple sessions per day (e.g. Asian + European)
   for(uint sessionIndex = 0; sessionIndex < 10; sessionIndex++)
   {
      datetime from = 0, to = 0;
      if(!SymbolInfoSessionTrade(symbol, (ENUM_SESSION_DAY_OF_WEEK)dayOfWeek, sessionIndex, from, to))
         break;  // No more sessions
      
      // Convert session times to seconds-since-midnight
      MqlDateTime fromDT, toDT;
      TimeToStruct(from, fromDT);
      TimeToStruct(to, toDT);
      int fromSeconds = fromDT.hour * 3600 + fromDT.min * 60 + fromDT.sec;
      int toSeconds   = toDT.hour * 3600 + toDT.min * 60 + toDT.sec;
      
      MqlDateTime mdt;
      TimeToStruct(now, mdt);
      int currentSeconds = mdt.hour * 3600 + mdt.min * 60 + mdt.sec;
      
      // Handle sessions that span midnight (toSeconds < fromSeconds)
      if(toSeconds > fromSeconds)
      {
         if(currentSeconds >= fromSeconds && currentSeconds <= toSeconds)
            return true;
      }
      else if(toSeconds < fromSeconds)
      {
         // Spans midnight: e.g. 23:00 to 01:00
         if(currentSeconds >= fromSeconds || currentSeconds <= toSeconds)
            return true;
      }
   }
   
   // If no sessions found for today, check if it's a weekday (market might still be open)
   // Some brokers don't define sessions for all days
   if(dayOfWeek >= 1 && dayOfWeek <= 5)
      return true;  // Assume open on weekdays if no session info available
   
   return false;
}

//+------------------------------------------------------------------+
//| Format double for display                                        |
//+------------------------------------------------------------------+
string FormatPrice(double price, string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return DoubleToString(price, digits);
}

//+------------------------------------------------------------------+
//| Get state name as string                                         |
//+------------------------------------------------------------------+
string StateToString(ENUM_ZONE_STATE state)
{
   switch(state)
   {
      case STATE_WAIT_ZONE:            return "WAIT_ZONE";
      case STATE_WAIT_INITIAL_BREAKOUT: return "WAIT_INITIAL_BREAKOUT";
      case STATE_IN_POSITION:          return "IN_POSITION";
      case STATE_SL_CLOSE_PENDING:     return "SL_CLOSE_PENDING";
      case STATE_REVERSAL_PENDING:     return "REVERSAL_PENDING";
      case STATE_WAIT_REENTRY:         return "WAIT_REENTRY";
      case STATE_NEWS_BLOCKED_DAY:     return "NEWS_BLOCKED_DAY";
      case STATE_NEWS_FORCED_CLOSE:    return "NEWS_FORCED_CLOSE";
      case STATE_DAY_END_CLOSE:        return "DAY_END_CLOSE";
      case STATE_DAY_COMPLETED:        return "DAY_COMPLETED";
      case STATE_RISK_HALT:            return "RISK_HALT";
      case STATE_RECOVERY_REQUIRED:    return "RECOVERY_REQUIRED";
      default:                         return "UNKNOWN";
   }
}

#endif // COMMON_DEFINES_MQH
//+------------------------------------------------------------------+
