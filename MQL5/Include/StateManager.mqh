//+------------------------------------------------------------------+
//|                                                  StateManager.mqh|
//|           State persistence, restoration, and logging             |
//+------------------------------------------------------------------+
#ifndef STATE_MANAGER_MQH
#define STATE_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| State data structure for binary serialization                     |
//+------------------------------------------------------------------+
struct EASerializedState
{
   ulong            ZoneID;
   double           ZoneHigh;
   double           ZoneLow;
   datetime         ZoneDate;
   ulong            CycleID;
   int              TradeNumber;
   double           CurrentLot;
   double           TotalCyclePnL;
   double           UnrecoveredLoss;
   ulong            PositionIdentifier;
   ENUM_SIGNAL_TYPE LastProcessedSignal;
   ENUM_ZONE_STATE  CurrentState;
   uint             StateChecksum;
   datetime         LastSavedTime;
   string           Symbol;
   ulong            Magic;
   int              PositionDirection;
};

//+------------------------------------------------------------------+
//| CStateManager class                                               |
//+------------------------------------------------------------------+
class CStateManager
{
private:
   string           m_symbol;
   ulong            m_magic;
   ENUM_ZONE_STATE  m_currentState;
   string           m_stateFilePath;
   string           m_tradeLogPath;
   string           m_cycleLogPath;
   bool             m_tradeLogHeaderWritten;
   bool             m_cycleLogHeaderWritten;
   
   //+------------------------------------------------------------------+
   //| Calculate checksum for state data                                |
   //+------------------------------------------------------------------+
   uint CalculateChecksum(const EASerializedState &state)
   {
      uint crc = 0;
      uchar data[];
      
      // Pack key fields into byte array
      int size = 0;
      ArrayResize(data, 200);
      
      // ZoneID
      ulong zid = state.ZoneID;
      for(int i = 0; i < 8; i++) { data[size++] = (uchar)(zid & 0xFF); zid >>= 8; }
      // CycleID
      ulong cid = state.CycleID;
      for(int i = 0; i < 8; i++) { data[size++] = (uchar)(cid & 0xFF); cid >>= 8; }
      // TradeNumber
      int tn = state.TradeNumber;
      for(int i = 0; i < 4; i++) { data[size++] = (uchar)(tn & 0xFF); tn >>= 8; }
      // CurrentState
      int cs = (int)state.CurrentState;
      for(int i = 0; i < 4; i++) { data[size++] = (uchar)(cs & 0xFF); cs >>= 8; }
      
      ArrayResize(data, size);
      
      // Simple CRC32-like checksum
      for(int i = 0; i < size; i++)
      {
         crc ^= data[i];
         for(int j = 0; j < 8; j++)
         {
            if((crc & 1) != 0)
               crc = (crc >> 1) ^ 0xEDB88320;
            else
               crc >>= 1;
         }
      }
      
      return crc;
   }

public:
   CStateManager()
   {
      m_currentState           = STATE_WAIT_ZONE;
      m_tradeLogHeaderWritten  = false;
      m_cycleLogHeaderWritten  = false;
   }
   
   void Init(string symbol, ulong magic)
   {
      m_symbol        = symbol;
      m_magic         = magic;
      m_stateFilePath = ZRE_STATE_FILE;
      m_tradeLogPath  = ZRE_TRADE_LOG_FILE;
      m_cycleLogPath  = ZRE_CYCLE_LOG_FILE;
   }
   
   //+------------------------------------------------------------------+
   //| Save complete state to binary file                               |
   //+------------------------------------------------------------------+
   bool SaveState(ENUM_ZONE_STATE state, const ZoneData &zone, const CycleData &cycle,
                  ENUM_SIGNAL_TYPE lastSignal, int posDir)
   {
      EASerializedState saveState;
      
      saveState.ZoneID              = zone.ZoneID;
      saveState.ZoneHigh            = zone.ZoneHigh;
      saveState.ZoneLow             = zone.ZoneLow;
      saveState.ZoneDate            = zone.ZoneTime;
      saveState.CycleID             = cycle.CycleID;
      saveState.TradeNumber         = cycle.TradeNumber;
      saveState.CurrentLot          = cycle.CurrentLot;
      saveState.TotalCyclePnL       = cycle.TotalCyclePnL;
      saveState.UnrecoveredLoss     = cycle.UnrecoveredLoss;
      saveState.PositionIdentifier  = cycle.PositionIdentifier;
      saveState.LastProcessedSignal = lastSignal;
      saveState.CurrentState        = state;
      saveState.LastSavedTime       = TimeCurrent();
      saveState.Symbol              = m_symbol;
      saveState.Magic               = m_magic;
      saveState.PositionDirection   = posDir;
      saveState.StateChecksum       = CalculateChecksum(saveState);
      
      // Write to binary file
      int fileHandle = FileOpen(m_stateFilePath, FILE_WRITE|FILE_BIN);
      if(fileHandle == INVALID_HANDLE)
      {
         // Try MQL5/Files
         fileHandle = FileOpen(m_stateFilePath, FILE_WRITE|FILE_BIN);
         if(fileHandle == INVALID_HANDLE)
         {
            PrintFormat("[StateManager] Failed to save state: %d", GetLastError());
            return false;
         }
      }
      
      // Write each field
      FileWriteInteger(fileHandle, (int)saveState.ZoneID);
      FileWriteDouble(fileHandle, saveState.ZoneHigh);
      FileWriteDouble(fileHandle, saveState.ZoneLow);
      FileWriteInteger(fileHandle, (int)saveState.ZoneDate);
      FileWriteInteger(fileHandle, (int)saveState.CycleID);
      FileWriteInteger(fileHandle, saveState.TradeNumber);
      FileWriteDouble(fileHandle, saveState.CurrentLot);
      FileWriteDouble(fileHandle, saveState.TotalCyclePnL);
      FileWriteDouble(fileHandle, saveState.UnrecoveredLoss);
      FileWriteInteger(fileHandle, (int)saveState.PositionIdentifier);
      FileWriteInteger(fileHandle, (int)saveState.LastProcessedSignal);
      FileWriteInteger(fileHandle, (int)saveState.CurrentState);
      FileWriteInteger(fileHandle, (int)saveState.StateChecksum);
      FileWriteInteger(fileHandle, (int)saveState.LastSavedTime);
      FileWriteString(fileHandle, saveState.Symbol, 20);
      FileWriteInteger(fileHandle, (int)saveState.Magic);
      FileWriteInteger(fileHandle, saveState.PositionDirection);
      
      FileClose(fileHandle);
      
      m_currentState = state;
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Load state from binary file                                      |
   //+------------------------------------------------------------------+
   bool LoadState(ENUM_ZONE_STATE &state, ZoneData &zone, CycleData &cycle,
                  ENUM_SIGNAL_TYPE &lastSignal, int &posDir)
   {
      int fileHandle = FileOpen(m_stateFilePath, FILE_READ|FILE_BIN);
      if(fileHandle == INVALID_HANDLE)
      {
         Print("[StateManager] No saved state found");
         return false;
      }
      
      EASerializedState loadedState;
      
      loadedState.ZoneID              = (ulong)FileReadInteger(fileHandle);
      loadedState.ZoneHigh            = FileReadDouble(fileHandle);
      loadedState.ZoneLow             = FileReadDouble(fileHandle);
      loadedState.ZoneDate            = (datetime)FileReadInteger(fileHandle);
      loadedState.CycleID             = (ulong)FileReadInteger(fileHandle);
      loadedState.TradeNumber         = FileReadInteger(fileHandle);
      loadedState.CurrentLot          = FileReadDouble(fileHandle);
      loadedState.TotalCyclePnL       = FileReadDouble(fileHandle);
      loadedState.UnrecoveredLoss     = FileReadDouble(fileHandle);
      loadedState.PositionIdentifier  = (ulong)FileReadInteger(fileHandle);
      loadedState.LastProcessedSignal = (ENUM_SIGNAL_TYPE)FileReadInteger(fileHandle);
      loadedState.CurrentState        = (ENUM_ZONE_STATE)FileReadInteger(fileHandle);
      loadedState.StateChecksum       = (uint)FileReadInteger(fileHandle);
      loadedState.LastSavedTime       = (datetime)FileReadInteger(fileHandle);
      loadedState.Symbol              = FileReadString(fileHandle);
      loadedState.Magic               = (ulong)FileReadInteger(fileHandle);
      loadedState.PositionDirection   = FileReadInteger(fileHandle);
      
      FileClose(fileHandle);
      
      // Verify checksum
      uint expectedChecksum = CalculateChecksum(loadedState);
      if(expectedChecksum != loadedState.StateChecksum)
      {
         Print("[StateManager] State file checksum mismatch - state corrupted");
         return false;
      }
      
      // Verify symbol and magic
      if(loadedState.Symbol != m_symbol)
      {
         PrintFormat("[StateManager] Symbol mismatch: saved=%s current=%s",
                     loadedState.Symbol, m_symbol);
         return false;
      }
      
      if(loadedState.Magic != m_magic)
      {
         PrintFormat("[StateManager] Magic mismatch: saved=%lu current=%lu",
                     loadedState.Magic, m_magic);
         return false;
      }
      
      // Verify position still exists if state says it should
      if(loadedState.CurrentState == STATE_IN_POSITION && loadedState.PositionIdentifier > 0)
      {
         if(!PositionSelectByTicket(loadedState.PositionIdentifier))
         {
            Print("[StateManager] Saved position no longer exists - adjusting state");
            loadedState.CurrentState = STATE_WAIT_REENTRY;
            loadedState.PositionIdentifier = 0;
         }
      }
      
      // Populate output parameters
      state = loadedState.CurrentState;
      
      zone.ZoneID   = loadedState.ZoneID;
      zone.ZoneHigh = loadedState.ZoneHigh;
      zone.ZoneLow  = loadedState.ZoneLow;
      zone.ZoneTime = loadedState.ZoneDate;
      zone.IsValid  = (zone.ZoneHigh > 0 && zone.ZoneLow > 0);
      
      cycle.CycleID            = loadedState.CycleID;
      cycle.TradeNumber        = loadedState.TradeNumber;
      cycle.CurrentLot         = loadedState.CurrentLot;
      cycle.TotalCyclePnL      = loadedState.TotalCyclePnL;
      cycle.UnrecoveredLoss    = loadedState.UnrecoveredLoss;
      cycle.PositionIdentifier = loadedState.PositionIdentifier;
      cycle.PositionDir        = (ENUM_POSITION_DIRECTION)loadedState.PositionDirection;
      cycle.IsActive           = (state == STATE_IN_POSITION);
      
      lastSignal = loadedState.LastProcessedSignal;
      posDir     = loadedState.PositionDirection;
      
      m_currentState = state;
      
      PrintFormat("[StateManager] State restored: State=%s ZoneID=%lu CycleID=%lu Trade#=%d",
                  StateToString(state), zone.ZoneID, cycle.CycleID, cycle.TradeNumber);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Log trade to CSV                                                 |
   //+------------------------------------------------------------------+
   void LogTrade(const TradeRecord &record)
   {
      int fileHandle = FileOpen(m_tradeLogPath, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         fileHandle = FileOpen(m_tradeLogPath, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
         if(fileHandle == INVALID_HANDLE) return;
         
         // Write header
         FileWrite(fileHandle, "TradeID", "CycleID", "ZoneID", "TradeNumber", "Direction",
                   "Lot", "EntryPrice", "ExitPrice", "TPPrice", "PnL", "CloseReason",
                   "OpenTime", "CloseTime");
      }
      
      FileSeek(fileHandle, 0, SEEK_END);
      
      string dirStr = (record.Direction == DIR_BUY) ? "BUY" : "SELL";
      
      FileWrite(fileHandle, 
                IntegerToString(record.TradeID),
                IntegerToString(record.CycleID),
                IntegerToString(record.ZoneID),
                IntegerToString(record.TradeNumber),
                dirStr,
                DoubleToString(record.Lot, 2),
                DoubleToString(record.EntryPrice, 5),
                DoubleToString(record.ExitPrice, 5),
                DoubleToString(record.TPPrice, 5),
                DoubleToString(record.PnL, 2),
                record.CloseReason,
                TimeToString(record.OpenTime),
                TimeToString(record.CloseTime));
      
      FileClose(fileHandle);
   }
   
   //+------------------------------------------------------------------+
   //| Log cycle to CSV                                                 |
   //+------------------------------------------------------------------+
   void LogCycle(ulong cycleID, ulong zoneID, int totalTrades, 
                 double totalPnL, double unrecoveredLoss, string endReason)
   {
      int fileHandle = FileOpen(m_cycleLogPath, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         fileHandle = FileOpen(m_cycleLogPath, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
         if(fileHandle == INVALID_HANDLE) return;
         
         FileWrite(fileHandle, "CycleID", "ZoneID", "TotalTrades", "TotalPnL",
                   "UnrecoveredLoss", "EndReason", "EndTime");
      }
      
      FileSeek(fileHandle, 0, SEEK_END);
      
      FileWrite(fileHandle,
                IntegerToString(cycleID),
                IntegerToString(zoneID),
                IntegerToString(totalTrades),
                DoubleToString(totalPnL, 2),
                DoubleToString(unrecoveredLoss, 2),
                endReason,
                TimeToString(TimeCurrent()));
      
      FileClose(fileHandle);
   }
   
   //+------------------------------------------------------------------+
   //| Delete saved state file                                          |
   //+------------------------------------------------------------------+
   void DeleteStateFile()
   {
      FileDelete(m_stateFilePath);
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   ENUM_ZONE_STATE GetCurrentState() const { return m_currentState; }
};

#endif // STATE_MANAGER_MQH
//+------------------------------------------------------------------+
