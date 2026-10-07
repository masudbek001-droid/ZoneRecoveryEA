//+------------------------------------------------------------------+
//|                                            PositionLockManager.mqh|
//|    Ensures only one position exists at a time for this EA         |
//+------------------------------------------------------------------+
#ifndef POSITION_LOCK_MANAGER_MQH
#define POSITION_LOCK_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CPositionLockManager class                                        |
//+------------------------------------------------------------------+
class CPositionLockManager
{
private:
   string           m_symbol;
   ulong            m_magic;
   ulong            m_lockedPositionTicket;
   bool             m_isLocked;
   
   //+------------------------------------------------------------------+
   //| GV key for this EA instance lock                                 |
   //+------------------------------------------------------------------+
   string GetLockKey()
   {
      return ZRE_GV_LOCK_PREFIX + IntegerToString(m_magic) + "_" + m_symbol;
   }
   
   //+------------------------------------------------------------------+
   //| GV key for position tracking                                     |
   //+------------------------------------------------------------------+
   string GetPositionKey()
   {
      return ZRE_GV_POSITION_KEY + IntegerToString(m_magic) + "_" + m_symbol;
   }

public:
   CPositionLockManager()
   {
      m_lockedPositionTicket = 0;
      m_isLocked = false;
   }
   
   void Init(string symbol, ulong magic)
   {
      m_symbol = symbol;
      m_magic  = magic;
      
      // Try to restore lock from GV
      string lockKey = GetLockKey();
      if(GlobalVariableCheck(lockKey))
      {
         double gvValue = GlobalVariableGet(lockKey);
         if(gvValue > 0)
         {
            m_lockedPositionTicket = (ulong)gvValue;
            
            // Verify the position still exists
            if(!PositionSelectByTicket(m_lockedPositionTicket))
            {
               // Position no longer exists - clear lock
               GlobalVariableDel(lockKey);
               m_lockedPositionTicket = 0;
               m_isLocked = false;
            }
            else
            {
               m_isLocked = true;
               PrintFormat("[PosLock] Lock restored from GV: Ticket=%lu", m_lockedPositionTicket);
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if we can open a new position                              |
   //+------------------------------------------------------------------+
   bool CanOpenPosition(string &reason)
   {
      reason = "";
      
      // 1. Check if we have an open position with our magic
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         
         reason = "Position already open: " + IntegerToString(ticket);
         return false;
      }
      
      // 2. Check if there's a GV lock
      string lockKey = GetLockKey();
      if(GlobalVariableCheck(lockKey))
      {
         double gvValue = GlobalVariableGet(lockKey);
         if(gvValue > 0)
         {
            ulong lockedTicket = (ulong)gvValue;
            if(PositionSelectByTicket(lockedTicket))
            {
               reason = "GV lock active for ticket: " + IntegerToString(lockedTicket);
               return false;
            }
            else
            {
               // Stale lock - clear it
               GlobalVariableDel(lockKey);
            }
         }
      }
      
      // 3. Check for pending orders
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetInteger(ORDER_MAGIC) != (long)m_magic) continue;
         if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
         
         reason = "Pending order exists: " + IntegerToString(ticket);
         return false;
      }
      
      // 4. Check internal lock
      if(m_isLocked)
      {
         if(PositionSelectByTicket(m_lockedPositionTicket))
         {
            reason = "Internal lock active for ticket: " + IntegerToString(m_lockedPositionTicket);
            return false;
         }
         m_isLocked = false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Lock a position (call after successful open)                     |
   //+------------------------------------------------------------------+
   void LockPosition(ulong ticket)
   {
      m_lockedPositionTicket = ticket;
      m_isLocked = true;
      
      // Set GV lock
      string lockKey = GetLockKey();
      GlobalVariableSet(lockKey, (double)ticket);
      
      PrintFormat("[PosLock] Position locked: Ticket=%lu", ticket);
   }
   
   //+------------------------------------------------------------------+
   //| Unlock position (call after position is confirmed closed)        |
   //+------------------------------------------------------------------+
   void UnlockPosition()
   {
      m_lockedPositionTicket = 0;
      m_isLocked = false;
      
      // Clear GV lock
      string lockKey = GetLockKey();
      if(GlobalVariableCheck(lockKey))
         GlobalVariableDel(lockKey);
      
      Print("[PosLock] Position unlocked");
   }
   
   //+------------------------------------------------------------------+
   //| Check account type                                               |
   //+------------------------------------------------------------------+
   bool ValidateAccountType(string &reason)
   {
      ENUM_ACCOUNT_MARGIN_MODE marginMode = 
         (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      
      if(marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         // Hedging mode - we can safely have separate positions
         return true;
      }
      
      if(marginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING)
      {
         // Netting mode - check for conflicts
         // In netting mode, positions for the same symbol are merged
         // This could cause issues if other strategies trade the same symbol
         int totalPositions = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != (long)m_magic)
            {
               reason = "NETTING MODE WARNING: Other positions exist for " + m_symbol + 
                        " with different magic numbers. Positions may merge.";
               Print("[PosLock] " + reason);
               // Don't block - just warn
            }
            totalPositions++;
         }
      }
      
      return true;  // Allow but warn
   }
   
   //+------------------------------------------------------------------+
   //| Get locked position ticket                                       |
   //+------------------------------------------------------------------+
   ulong GetLockedTicket() const { return m_lockedPositionTicket; }
   bool IsLocked() const { return m_isLocked; }
};

#endif // POSITION_LOCK_MANAGER_MQH
//+------------------------------------------------------------------+
