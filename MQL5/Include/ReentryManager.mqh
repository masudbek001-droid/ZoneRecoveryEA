//+------------------------------------------------------------------+
//|                                                ReentryManager.mqh|
//|        Post-TP re-entry cycle management                          |
//+------------------------------------------------------------------+
#ifndef REENTRY_MANAGER_MQH
#define REENTRY_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CReentryManager class                                             |
//+------------------------------------------------------------------+
class CReentryManager
{
private:
   string           m_symbol;
   bool             m_active;            // Is re-entry mode active?
   bool             m_touchConfirmed;    // Has the touch been confirmed?
   ENUM_SIGNAL_TYPE m_pendingSignal;     // Signal waiting to be executed
   
public:
   CReentryManager()
   {
      m_active          = false;
      m_touchConfirmed  = false;
      m_pendingSignal   = SIGNAL_NONE;
   }
   
   void Init(string symbol)
   {
      m_symbol = symbol;
   }
   
   //+------------------------------------------------------------------+
   //| Activate re-entry mode after TP                                  |
   //+------------------------------------------------------------------+
   void Activate()
   {
      m_active         = true;
      m_touchConfirmed = false;
      m_pendingSignal  = SIGNAL_NONE;
      Print("[ReentryManager] Re-entry mode activated");
   }
   
   //+------------------------------------------------------------------+
   //| Deactivate re-entry mode                                         |
   //+------------------------------------------------------------------+
   void Deactivate()
   {
      m_active         = false;
      m_touchConfirmed = false;
      m_pendingSignal  = SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Check if re-entry mode is active                                 |
   //+------------------------------------------------------------------+
   bool IsActive() const { return m_active; }
   
   //+------------------------------------------------------------------+
   //| Check for re-entry touch signal                                  |
   //| Price must go outside zone, then come back to touch boundary     |
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE CheckTouch(double zoneHigh, double zoneLow, 
                                double touchTolerancePips, double maxOvershootPips)
   {
      if(!m_active)
         return SIGNAL_NONE;
      
      if(m_touchConfirmed)
         return SIGNAL_NONE;
      
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      double tolerance   = PipsToPrice(m_symbol, touchTolerancePips);
      double maxOvershoot = PipsToPrice(m_symbol, maxOvershootPips);
      
      // Check if price is currently above zone
      if(ask > zoneHigh)
      {
         // Price is above - check if it touches ZoneHigh from above
         if(bid <= zoneHigh + tolerance && bid >= zoneHigh - tolerance)
         {
            // Check max overshoot
            if(ask <= zoneHigh + maxOvershoot + tolerance)
            {
               m_touchConfirmed = true;
               m_pendingSignal  = SIGNAL_BUY_REENTRY;
               PrintFormat("[ReentryManager] BUY re-entry touch detected at bid=%.5f zoneHigh=%.5f",
                           bid, zoneHigh);
               return SIGNAL_BUY_REENTRY;
            }
         }
      }
      
      // Check if price is currently below zone
      if(bid < zoneLow)
      {
         // Price is below - check if it touches ZoneLow from below
         if(ask >= zoneLow - tolerance && ask <= zoneLow + tolerance)
         {
            if(bid >= zoneLow - maxOvershoot - tolerance)
            {
               m_touchConfirmed = true;
               m_pendingSignal  = SIGNAL_SELL_REENTRY;
               PrintFormat("[ReentryManager] SELL re-entry touch detected at ask=%.5f zoneLow=%.5f",
                           ask, zoneLow);
               return SIGNAL_SELL_REENTRY;
            }
         }
      }
      
      return SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Reset after re-entry trade opened                                |
   //+------------------------------------------------------------------+
   void ResetAfterTrade()
   {
      m_touchConfirmed = false;
      m_pendingSignal  = SIGNAL_NONE;
      // Stay active for potential next re-entry after this cycle ends
   }
   
   //+------------------------------------------------------------------+
   //| Full reset                                                       |
   //+------------------------------------------------------------------+
   void Reset()
   {
      m_active         = false;
      m_touchConfirmed = false;
      m_pendingSignal  = SIGNAL_NONE;
   }
   
   //+------------------------------------------------------------------+
   //| Set state                                                        |
   //+------------------------------------------------------------------+
   void SetActive(bool active) { m_active = active; }
};

#endif // REENTRY_MANAGER_MQH
//+------------------------------------------------------------------+
