//+------------------------------------------------------------------+
//|                                               VisualManager.mqh  |
//|            Chart visualization and info panel                     |
//+------------------------------------------------------------------+
#ifndef VISUAL_MANAGER_MQH
#define VISUAL_MANAGER_MQH

#include "CommonDefines.mqh"

//+------------------------------------------------------------------+
//| CVisualManager class                                              |
//+------------------------------------------------------------------+
class CVisualManager
{
private:
   string           m_symbol;
   long             m_chartID;
   
   // Zone display
   string           m_zoneHighLine;
   string           m_zoneLowLine;
   string           m_zoneRect;
   string           m_zoneLabel;
   
   // Info panel
   string           m_panelPrefix;
   int              m_panelX;
   int              m_panelY;
   color            m_panelColor;
   int              m_panelFontSize;
   
   // Colors
   color            m_zoneHighColor;
   color            m_zoneLowColor;
   color            m_zoneFillColor;
   int              m_zoneLineThickness;
   int              m_zoneFillOpacity;
   
   bool             m_showPreviousZones;
   
   //+------------------------------------------------------------------+
   //| Create a text label on chart                                     |
   //+------------------------------------------------------------------+
   void CreateLabel(string name, string text, int x, int y, color clr, int fontSize = 9)
   {
      if(ObjectFind(m_chartID, name) < 0)
         ObjectCreate(m_chartID, name, OBJ_LABEL, 0, 0, 0);
      
      ObjectSetInteger(m_chartID, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(m_chartID, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(m_chartID, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(m_chartID, name, OBJPROP_TEXT, text);
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(m_chartID, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(m_chartID, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(m_chartID, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartID, name, OBJPROP_HIDDEN, true);
   }
   
   //+------------------------------------------------------------------+
   //| Create section header                                            |
   //+------------------------------------------------------------------+
   void CreateSectionHeader(string name, string text, int x, int y)
   {
      CreateLabel(name, text, x, y, clrYellow, 10);
   }

public:
   CVisualManager()
   {
      m_chartID           = 0;
      m_panelX            = 10;
      m_panelY            = 30;
      m_panelColor        = clrWhite;
      m_panelFontSize     = 9;
      m_zoneHighColor     = clrDodgerBlue;
      m_zoneLowColor      = clrDodgerBlue;
      m_zoneFillColor     = clrDodgerBlue;
      m_zoneLineThickness = 2;
      m_zoneFillOpacity   = 30;
      m_showPreviousZones = false;
   }
   
   void Init(string symbol, color zoneColor, int zoneThickness, int zoneOpacity,
             bool showPrevious, int panelX, int panelY)
   {
      m_symbol            = symbol;
      m_chartID           = ChartID();
      m_zoneHighColor     = zoneColor;
      m_zoneLowColor      = zoneColor;
      m_zoneFillColor     = zoneColor;
      m_zoneLineThickness = zoneThickness;
      m_zoneFillOpacity   = zoneOpacity;
      m_showPreviousZones = showPrevious;
      m_panelX            = panelX;
      m_panelY            = panelY;
      
      m_zoneHighLine = "ZRE_ZoneHigh";
      m_zoneLowLine  = "ZRE_ZoneLow";
      m_zoneRect     = "ZRE_ZoneRect";
      m_zoneLabel    = "ZRE_ZoneLabel";
      m_panelPrefix  = "ZRE_Panel_";
   }
   
   //+------------------------------------------------------------------+
   //| Draw zone on chart                                               |
   //+------------------------------------------------------------------+
   void DrawZone(const ZoneData &zone, datetime visibleFrom, datetime visibleTo)
   {
      if(!zone.IsValid) return;
      
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      
      // Zone High line
      if(ObjectFind(m_chartID, m_zoneHighLine) < 0)
         ObjectCreate(m_chartID, m_zoneHighLine, OBJ_HLINE, 0, 0, zone.ZoneHigh);
      ObjectSetDouble(m_chartID, m_zoneHighLine, OBJPROP_PRICE, zone.ZoneHigh);
      ObjectSetInteger(m_chartID, m_zoneHighLine, OBJPROP_COLOR, m_zoneHighColor);
      ObjectSetInteger(m_chartID, m_zoneHighLine, OBJPROP_WIDTH, m_zoneLineThickness);
      ObjectSetString(m_chartID, m_zoneHighLine, OBJPROP_TOOLTIP, 
                      "Zone High: " + DoubleToString(zone.ZoneHigh, digits));
      
      // Zone Low line
      if(ObjectFind(m_chartID, m_zoneLowLine) < 0)
         ObjectCreate(m_chartID, m_zoneLowLine, OBJ_HLINE, 0, 0, zone.ZoneLow);
      ObjectSetDouble(m_chartID, m_zoneLowLine, OBJPROP_PRICE, zone.ZoneLow);
      ObjectSetInteger(m_chartID, m_zoneLowLine, OBJPROP_COLOR, m_zoneLowColor);
      ObjectSetInteger(m_chartID, m_zoneLowLine, OBJPROP_WIDTH, m_zoneLineThickness);
      ObjectSetString(m_chartID, m_zoneLowLine, OBJPROP_TOOLTIP,
                      "Zone Low: " + DoubleToString(zone.ZoneLow, digits));
      
      // Zone rectangle
      if(ObjectFind(m_chartID, m_zoneRect) < 0)
         ObjectCreate(m_chartID, m_zoneRect, OBJ_RECTANGLE, 0, 
                      zone.ZoneTime, zone.ZoneHigh, visibleTo, zone.ZoneLow);
      else
      {
         ObjectSetInteger(m_chartID, m_zoneRect, OBJPROP_TIME, 0, zone.ZoneTime);
         ObjectSetDouble(m_chartID, m_zoneRect, OBJPROP_PRICE, 0, zone.ZoneHigh);
         ObjectSetInteger(m_chartID, m_zoneRect, OBJPROP_TIME, 1, visibleTo);
         ObjectSetDouble(m_chartID, m_zoneRect, OBJPROP_PRICE, 1, zone.ZoneLow);
      }
      ObjectSetInteger(m_chartID, m_zoneRect, OBJPROP_COLOR, m_zoneFillColor);
      ObjectSetInteger(m_chartID, m_zoneRect, OBJPROP_FILL, true);
      ObjectSetInteger(m_chartID, m_zoneRect, OBJPROP_BACK, true);
      
      // Zone size label in the middle
      string labelText = StringFormat("ZONE SIZE: %.1f PIPS", zone.ZonePips);
      datetime midTime = zone.ZoneTime + (visibleTo - zone.ZoneTime) / 2;
      double midPrice = (zone.ZoneHigh + zone.ZoneLow) / 2.0;
      
      if(ObjectFind(m_chartID, m_zoneLabel) < 0)
         ObjectCreate(m_chartID, m_zoneLabel, OBJ_TEXT, 0, midTime, midPrice);
      else
         ObjectSetDouble(m_chartID, m_zoneLabel, OBJPROP_PRICE, midPrice);
      ObjectSetInteger(m_chartID, m_zoneLabel, OBJPROP_TIME, 0, midTime);
      ObjectSetString(m_chartID, m_zoneLabel, OBJPROP_TEXT, labelText);
      ObjectSetInteger(m_chartID, m_zoneLabel, OBJPROP_COLOR, m_zoneFillColor);
      ObjectSetInteger(m_chartID, m_zoneLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetString(m_chartID, m_zoneLabel, OBJPROP_FONT, "Consolas");
   }
   
   //+------------------------------------------------------------------+
   //| Update info panel                                                |
   //+------------------------------------------------------------------+
   void UpdatePanel(const ZoneData &zone, const CycleData &cycle,
                    ENUM_ZONE_STATE state, double currentPnL,
                    string brokerTime, string remainingTime, string dayStatus,
                    string newsStatus, string nextBlockedDate, string calendarStatus,
                    string relatedCurrencies,
                    int totalTrades, int totalCycles, int tpCycles, int dayEndCycles,
                    int newsClosures, double maxLot, double maxDD, double netProfit,
                    double requiredLot, double recoveryTarget)
   {
      int x = m_panelX;
      int y = m_panelY;
      int dy = 16;  // Line height
      int sectionGap = 8;
      
      // ZONE section
      CreateSectionHeader(m_panelPrefix + "hdr_zone", "=== ZONE ===", x, y);
      y += dy;
      CreateLabel(m_panelPrefix + "zh", "Zone High: " + FormatPrice(zone.ZoneHigh, m_symbol), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "zl", "Zone Low:  " + FormatPrice(zone.ZoneLow, m_symbol), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "zs", StringFormat("Zone Size: %.1f pips", zone.ZonePips), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "ztf", "Zone TF: " + EnumToString(zone.ZoneTimeframe), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "zstatus", "Zone Status: " + (zone.IsValid ? "ACTIVE" : "NOT SET"), x, y, zone.IsValid ? clrLime : clrGray, m_panelFontSize);
      y += dy + sectionGap;
      
      // CURRENT TRADE section
      CreateSectionHeader(m_panelPrefix + "hdr_trade", "=== CURRENT TRADE ===", x, y);
      y += dy;
      string dirStr = "None";
      color dirClr = clrGray;
      if(cycle.PositionDir == DIR_BUY) { dirStr = "BUY"; dirClr = clrLime; }
      else if(cycle.PositionDir == DIR_SELL) { dirStr = "SELL"; dirClr = clrRed; }
      CreateLabel(m_panelPrefix + "tdir", "Direction: " + dirStr, x, y, dirClr, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "tlot", StringFormat("Current Lot: %.2f", cycle.CurrentLot), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "tent", "Entry: " + FormatPrice(cycle.EntryPrice, m_symbol), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "ttp", "TP: " + FormatPrice(cycle.TPPrice, m_symbol), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      color pnlClr = (currentPnL >= 0) ? clrLime : clrRed;
      CreateLabel(m_panelPrefix + "tpnl", StringFormat("Current PnL: %.2f", currentPnL), x, y, pnlClr, m_panelFontSize);
      y += dy + sectionGap;
      
      // RECOVERY section
      CreateSectionHeader(m_panelPrefix + "hdr_rec", "=== RECOVERY ===", x, y);
      y += dy;
      CreateLabel(m_panelPrefix + "rcyc", StringFormat("Cycle ID: %lu", cycle.CycleID), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "rtn", StringFormat("Trade Number: %d", cycle.TradeNumber), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      color lossClr = (cycle.UnrecoveredLoss > 0) ? clrRed : clrLime;
      CreateLabel(m_panelPrefix + "rloss", StringFormat("Cycle Loss: %.2f", cycle.UnrecoveredLoss), x, y, lossClr, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "rtarget", StringFormat("Recovery Target: %.2f", recoveryTarget), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "rlot", StringFormat("Required Next Lot: %.2f", requiredLot), x, y, m_panelColor, m_panelFontSize);
      y += dy + sectionGap;
      
      // DAILY SESSION section
      CreateSectionHeader(m_panelPrefix + "hdr_daily", "=== DAILY SESSION ===", x, y);
      y += dy;
      CreateLabel(m_panelPrefix + "dtime", "Broker Time: " + brokerTime, x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "dremain", "Remaining: " + remainingTime, x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "dstatus", "Day Status: " + dayStatus, x, y, m_panelColor, m_panelFontSize);
      y += dy + sectionGap;
      
      // NEWS FILTER section
      CreateSectionHeader(m_panelPrefix + "hdr_news", "=== NEWS FILTER ===", x, y);
      y += dy;
      CreateLabel(m_panelPrefix + "ncur", "Currencies: " + relatedCurrencies, x, y, m_panelColor, m_panelFontSize);
      y += dy;
      color newsClr = (newsStatus == "CLEAR") ? clrLime : clrRed;
      CreateLabel(m_panelPrefix + "nstatus", "Today: " + newsStatus, x, y, newsClr, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "nnext", "Next Blocked: " + nextBlockedDate, x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "ncal", "Calendar: " + calendarStatus, x, y, m_panelColor, m_panelFontSize);
      y += dy + sectionGap;
      
      // STATISTICS section
      CreateSectionHeader(m_panelPrefix + "hdr_stats", "=== STATISTICS ===", x, y);
      y += dy;
      CreateLabel(m_panelPrefix + "strades", StringFormat("Total Trades: %d", totalTrades), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "scycles", StringFormat("Total Cycles: %d", totalCycles), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "stpcyc", StringFormat("TP Cycles: %d", tpCycles), x, y, clrLime, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "sdayend", StringFormat("Day-End Closes: %d", dayEndCycles), x, y, clrYellow, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "snewsc", StringFormat("News Closures: %d", newsClosures), x, y, clrOrange, m_panelFontSize);
      y += dy;
      CreateLabel(m_panelPrefix + "smaxlot", StringFormat("Max Lot: %.2f", maxLot), x, y, m_panelColor, m_panelFontSize);
      y += dy;
      color ddClr = (maxDD > 0) ? clrOrange : clrLime;
      CreateLabel(m_panelPrefix + "smaxdd", StringFormat("Max DD: %.2f%%", maxDD), x, y, ddClr, m_panelFontSize);
      y += dy;
      color npClr = (netProfit >= 0) ? clrLime : clrRed;
      CreateLabel(m_panelPrefix + "snetp", StringFormat("Net Profit: %.2f", netProfit), x, y, npClr, m_panelFontSize);
      y += dy;
      
      // State indicator
      CreateLabel(m_panelPrefix + "state", "STATE: " + StateToString(state), x, y, clrYellow, 11);
      
      ChartRedraw(m_chartID);
   }
   
   //+------------------------------------------------------------------+
   //| Draw forced close marker                                         |
   //+------------------------------------------------------------------+
   void DrawCloseMarker(datetime time, double price, string reason)
   {
      string name = "ZRE_Close_" + TimeToString(time, TIME_DATE|TIME_MINUTES);
      ObjectCreate(m_chartID, name, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(m_chartID, name, OBJPROP_ARROWCODE, 251);  // X mark
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, 2);
      ObjectSetString(m_chartID, name, OBJPROP_TOOLTIP, reason);
   }
   
   //+------------------------------------------------------------------+
   //| Draw trade entry marker                                          |
   //+------------------------------------------------------------------+
   void DrawEntryMarker(datetime time, double price, bool isBuy)
   {
      string name = "ZRE_Entry_" + TimeToString(time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      ObjectCreate(m_chartID, name, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(m_chartID, name, OBJPROP_ARROWCODE, isBuy ? 233 : 234);  // Up/Down arrow
      ObjectSetInteger(m_chartID, name, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
      ObjectSetInteger(m_chartID, name, OBJPROP_WIDTH, 2);
   }
   
   //+------------------------------------------------------------------+
   //| Clean up all objects                                             |
   //+------------------------------------------------------------------+
   void Cleanup()
   {
      // Delete zone objects
      ObjectDelete(m_chartID, m_zoneHighLine);
      ObjectDelete(m_chartID, m_zoneLowLine);
      ObjectDelete(m_chartID, m_zoneRect);
      ObjectDelete(m_chartID, m_zoneLabel);
      
      // Delete panel objects
      int total = ObjectsTotal(m_chartID);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(m_chartID, i);
         if(StringFind(name, m_panelPrefix) == 0)
            ObjectDelete(m_chartID, name);
      }
      
      ChartRedraw(m_chartID);
   }
   
   //+------------------------------------------------------------------+
   //| Getters/Setters                                                  |
   //+------------------------------------------------------------------+
   void SetShowPreviousZones(bool show) { m_showPreviousZones = show; }
};

#endif // VISUAL_MANAGER_MQH
//+------------------------------------------------------------------+
