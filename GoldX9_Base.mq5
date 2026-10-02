#property strict
#property version   "1.00"
#property description "Gold X9 strategy 9 base EA reconstructed from the supplied transcript."

#include <Trade/Trade.mqh>

enum LotMode { LOT_FIXED=0, LOT_RISK_PERCENT=1 };

input group "Trade setup"
input ulong   InpMagic                 = 900009;
input string  InpComment               = "GoldX9 strategy 9";
input LotMode InpLotMode               = LOT_RISK_PERCENT;
input double  InpFixedLots             = 0.01;
input double  InpRiskPercent           = 0.50;
input int     InpMaxPending            = 3;
input int     InpMaxPositions          = 10;
input int     InpPendingExpiryHours    = 15;
input int     InpDuplicatePoints       = 100;

input group "Structure"
input ENUM_TIMEFRAMES InpFractalTF     = PERIOD_H1;
input int     InpRescanMinutes         = 15;
input int     InpFractalLeft           = 5;
input int     InpFractalRight          = 5;
input int     InpMaxSearchBars         = 200;
input double  InpMinFractalClearancePct= 0.02;

input group "Entry and exits (percent of price)"
input double  InpBuyEntryOffsetPct     = -0.10;
input double  InpSellEntryOffsetPct    = -0.10;
input double  InpStopLossPct           = 2.00;
input double  InpTakeProfitPct         = 1.00;
input double  InpTrailTriggerPct       = 0.20;
input double  InpTrailDistancePct      = 0.20;
input double  InpMaxTrailPct           = 1.00;
input double  InpSalvageTriggerPct     = 1.00;
input double  InpSalvageExitPct        = 0.15;
input double  InpBreakEvenTriggerPct   = 0.10;
input double  InpBreakEvenLockPct      = 0.025;

CTrade trade;
datetime g_last_scan=0;
double g_point, g_tick_size, g_tick_value;
int g_digits;

double Pct(double price,double pct) { return price*pct/100.0; }
double N(double price) { return NormalizeDouble(price,g_digits); }

bool OurOrder(ulong ticket)
{
   if(!OrderSelect(ticket)) return false;
   return (OrderGetString(ORDER_SYMBOL)==_Symbol &&
           (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic);
}
bool OurPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   return (PositionGetString(POSITION_SYMBOL)==_Symbol &&
           (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic);
}

int CountPositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(OurPosition(PositionGetTicket(i))) n++;
   return n;
}
int CountPending(ENUM_ORDER_TYPE type)
{
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(OurOrder(t) && (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type) n++;
   }
   return n;
}

double LotsForRisk(double entry,double sl)
{
   if(InpLotMode==LOT_FIXED) return InpFixedLots;
   double risk_money=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
   double distance=MathAbs(entry-sl);
   if(distance<=0 || g_tick_size<=0 || g_tick_value<=0) return InpFixedLots;
   double lots=risk_money/(distance/g_tick_size*g_tick_value);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lots=MathMax(vmin,MathMin(vmax,lots));
   return NormalizeDouble(MathFloor(lots/vstep)*vstep,2);
}

bool IsSwingHigh(const MqlRates &r[],int i)
{
   for(int k=1;k<=InpFractalLeft;k++) if(r[i].high<=r[i+k].high) return false;
   for(int k=1;k<=InpFractalRight;k++) if(r[i].high<=r[i-k].high) return false;
   return true;
}
bool IsSwingLow(const MqlRates &r[],int i)
{
   for(int k=1;k<=InpFractalLeft;k++) if(r[i].low>=r[i+k].low) return false;
   for(int k=1;k<=InpFractalRight;k++) if(r[i].low>=r[i-k].low) return false;
   return true;
}

double FindSwing(bool high)
{
   MqlRates r[]; ArraySetAsSeries(r,true);
   int need=InpMaxSearchBars+InpFractalLeft+InpFractalRight+5;
   if(CopyRates(_Symbol,InpFractalTF,0,need,r)<need) return 0;
   int first=InpFractalRight+1;
   int last=MathMin(InpMaxSearchBars,ArraySize(r)-InpFractalLeft-1);
   for(int i=first;i<=last;i++)
      if(high ? IsSwingHigh(r,i) : IsSwingLow(r,i)) return high?r[i].high:r[i].low;
   return 0;
}

bool SimilarPending(ENUM_ORDER_TYPE type,double price)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(OurOrder(t) && (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type)
         if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-price)<=InpDuplicatePoints*g_point) return true;
   }
   return false;
}

void PlaceBreakout(bool buy)
{
   ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP;
   if(CountPending(type)>=InpMaxPending) return;
   double swing=FindSwing(buy); if(swing<=0) return;
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double market=buy?ask:bid;
   if(buy && market>=swing-Pct(swing,InpMinFractalClearancePct)) return;
   if(!buy && market<=swing+Pct(swing,InpMinFractalClearancePct)) return;
   double entry=buy?swing+Pct(swing,InpBuyEntryOffsetPct):swing-Pct(swing,InpSellEntryOffsetPct);
   entry=N(entry); if(SimilarPending(type,entry)) return;
   double sl=buy?entry-Pct(entry,InpStopLossPct):entry+Pct(entry,InpStopLossPct);
   double tp=buy?entry+Pct(entry,InpTakeProfitPct):entry-Pct(entry,InpTakeProfitPct);
   sl=N(sl); tp=N(tp);
   double stop_level=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*g_point;
   if(buy && entry<=ask+stop_level) return;
   if(!buy && entry>=bid-stop_level) return;
   double lots=LotsForRisk(entry,sl); if(lots<=0) return;
   datetime expiry=InpPendingExpiryHours>0 ? TimeCurrent()+InpPendingExpiryHours*3600 : 0;
   trade.SetExpertMagicNumber(InpMagic);
   bool ok=buy ? trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,expiry,InpComment)
               : trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_GTC,expiry,InpComment);
   if(!ok) Print("Pending order failed: ",trade.ResultRetcodeDescription());
}

void ManagePositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i); if(!OurPosition(ticket)) continue;
      long type=PositionGetInteger(POSITION_TYPE);
      double open=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL), tp=PositionGetDouble(POSITION_TP);
      double price=(type==POSITION_TYPE_BUY)?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double move=type==POSITION_TYPE_BUY ? price-open : open-price;
      double favorable_pct=move/open*100.0;
      double loss_pct=(-move)/open*100.0;
      double new_sl=sl, new_tp=tp;
      if(favorable_pct>=InpBreakEvenTriggerPct)
         new_sl=type==POSITION_TYPE_BUY?MathMax(new_sl,open+Pct(open,InpBreakEvenLockPct)):MathMin(new_sl,open-Pct(open,InpBreakEvenLockPct));
      if(favorable_pct>=InpTrailTriggerPct && favorable_pct<=InpMaxTrailPct)
         new_sl=type==POSITION_TYPE_BUY?MathMax(new_sl,price-Pct(price,InpTrailDistancePct)):MathMin(new_sl,price+Pct(price,InpTrailDistancePct));
      if(loss_pct>=InpSalvageTriggerPct)
         new_tp=type==POSITION_TYPE_BUY?open-Pct(open,InpSalvageExitPct):open+Pct(open,InpSalvageExitPct);
      new_sl=N(new_sl); new_tp=N(new_tp);
      if(new_sl!=sl || new_tp!=tp) trade.PositionModify(ticket,new_sl,new_tp);
   }
}

int OnInit()
{
   g_point=SymbolInfoDouble(_Symbol,SYMBOL_POINT); g_digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   g_tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); g_tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   if(InpFractalLeft<1 || InpFractalRight<1 || InpMaxPending<1 || InpMaxPositions<1) return INIT_PARAMETERS_INCORRECT;
   trade.SetExpertMagicNumber(InpMagic); return INIT_SUCCEEDED;
}

void OnTick()
{
   ManagePositions();
   if(CountPositions()>=InpMaxPositions) return;
   datetime now=TimeCurrent();
   if(g_last_scan!=0 && now-g_last_scan<InpRescanMinutes*60) return;
   g_last_scan=now;
   PlaceBreakout(true); PlaceBreakout(false);
}
