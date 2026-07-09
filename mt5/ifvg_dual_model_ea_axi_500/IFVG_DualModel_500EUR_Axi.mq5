//+------------------------------------------------------------------+
//|                        IFVG_DualModel_500EUR_Axi.mq5              |
//|                                                     txatxe.code  |
//|                                                                  |
//| VERSION PARA AXI BTCUSD (500 EUR):                               |
//| Ambos modelos IFVG activos (M1 para Modelo 1, M1 para Modelo 2). |
//| Todos los parámetros adaptados a puntos x100 (punto = $0.01).    |
//|   SL 15000 (=$150) - trailing 7500/5000                          |
//|   FVG min 1000 (M1) - spread max 3000 (=$30)                     |
//|   Riesgo: 0.5% = 2.50€ por operación                             |
//|                                                                  |
//| Modelo 1: bias M1 (MSS) -> IFVG M1 -> entrada por retest        |
//| Modelo 2: sweep M1 -> displacement -> IFVG M1 -> entrada retest  |
//+------------------------------------------------------------------+
#property copyright "txatxe.code"
#property link      "https://github.com/txaaatxee"
#property version   "1.00"

#include <Trade\Trade.mqh>

enum ENUM_EXIT_MODE
  {
   EXIT_TRAILING = 0,
   EXIT_FIXED_RR = 1
  };

input group "=== General ==="
input long              InpMagic            = 20260712;   // Magic number
input int               InpMaxSpreadPoints  = 3000;       // Spread máximo (puntos)
input int               InpMaxOpenPositions = 10;         // Máx posiciones abiertas

input group "=== Modelo 1 (M1 bias -> M1 IFVG) ==="
input ENUM_TIMEFRAMES   InpM1BiasTF         = PERIOD_M1;  // TF de bias
input ENUM_TIMEFRAMES   InpM1EntryTF        = PERIOD_M1;  // TF de entrada
input int               InpM1SwingBars      = 3;          // Barras fractal
input int               InpM1BiasLookback   = 40;         // Lookback para bias
input int               InpM1FvgMinPoints   = 1000;       // FVG mínimo (puntos)
input int               InpM1ZoneExpiryBars = 120;        // Expiración zona

input group "=== Modelo 2 (M1 sweep -> M1 displacement -> M1 IFVG) ==="
input ENUM_TIMEFRAMES   InpM2TF             = PERIOD_M1;  // TF del modelo 2
input int               InpM2SweepLookback  = 30;         // Lookback sweep
input int               InpM2SweepWindow    = 15;         // Ventana post-sweep
input double            InpM2DispFactor     = 1.8;        // Factor displacement
input int               InpM2AvgBodyBars    = 20;         // Barras cuerpo medio
input int               InpM2FvgMinPoints   = 500;        // FVG mínimo
input int               InpM2MinRangePoints = 15000;      // Rango mínimo reciente
input int               InpM2RangeBars      = 15;         // Barras para rango
input int               InpM2ZoneExpiryBars = 90;         // Expiración zona

input group "=== Gestión (500 EUR) ==="
input double            InpInitialBalance   = 500.0;      // Balance inicial
input double            InpBaseLot          = 0.01;       // Lote base
input double            InpLotStepPer1000   = 0.02;       // Lotes extra per $1000
input double            InpMaxLot           = 0.5;        // Lote máximo
input int               InpStopPoints       = 15000;      // Stop loss (puntos)
input int               InpMaxOpenLosing    = 2;          // Max posiciones en negativo
input double            InpMaxOpenRiskPct   = 30.0;       // Riesgo máximo abierto (%)

input group "=== Salida ==="
input ENUM_EXIT_MODE    InpExitMode         = EXIT_TRAILING;
input int               InpTrailStartPoints = 7500;       // Trailing start
input int               InpTrailDistPoints  = 5000;       // Trailing distance
input double            InpFixedRR          = 2.5;        // RR si TP fijo

//--- estructura FVG / IFVG
struct SFvg
  {
   datetime          time;
   double            top;
   double            bottom;
   bool              bullish;
   bool              inverted;
   datetime          invTime;
   bool              armed;
   bool              traded;
   int               model;
  };

CTrade   g_trade;
SFvg     g_fvgM1[];
SFvg     g_fvgM2[];
datetime g_lastBarM1 = 0;
datetime g_lastBarM2 = 0;

int      g_m2SweepDir  = 0;
datetime g_m2SweepTime = 0;

double   g_initialBalance = 0.0;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);

   ArrayResize(g_fvgM1, 0);
   ArrayResize(g_fvgM2, 0);

   g_initialBalance = InpInitialBalance;

   if(MathAbs(_Point - 0.01) > 1e-10)
      PrintFormat("AVISO: %s cotiza con punto=%.5f, pero los parametros estan"
                  " calibrados para punto=0.01 (Axi, 2 digitos). Revisa SL/trailing"
                  " antes de operar.", _Symbol, _Point);

   PrintFormat("IFVG DualModel 500EUR iniciado. Magic=%I64d Balance=%.2f"
               " Modelo1=M1+M1 Modelo2=M1sweep+M1", InpMagic, g_initialBalance);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(InpExitMode == EXIT_TRAILING)
      ManageTrailing();

   if(IsNewBar(InpM1EntryTF, g_lastBarM1))
     {
      UpdateModel1();
     }
   if(IsNewBar(InpM2TF, g_lastBarM2))
     {
      UpdateModel2();
     }

   CheckRetestEntries(g_fvgM1, InpM1EntryTF);
   CheckRetestEntries(g_fvgM2, InpM2TF);

   UpdatePanel();
  }

//+------------------------------------------------------------------+
bool IsNewBar(const ENUM_TIMEFRAMES tf, datetime &lastBar)
  {
   datetime t = iTime(_Symbol, tf, 0);
   if(t == 0 || t == lastBar)
      return(false);
   lastBar = t;
   return(true);
  }

//+------------------------------------------------------------------+
void UpdateModel1()
  {
   DetectNewFvg(g_fvgM1, InpM1EntryTF, InpM1FvgMinPoints, 1);
   ExpireZones(g_fvgM1, InpM1EntryTF, InpM1ZoneExpiryBars);

   int bias = Model1Bias();
   if(bias == 0)
      return;

   for(int i = 0; i < ArraySize(g_fvgM1); i++)
     {
      if(g_fvgM1[i].inverted || g_fvgM1[i].traded)
         continue;
      if(!IsInverted(g_fvgM1[i], InpM1EntryTF))
         continue;

      g_fvgM1[i].inverted = true;
      g_fvgM1[i].invTime  = iTime(_Symbol, InpM1EntryTF, 1);

      bool longSetup  = (bias > 0 && !g_fvgM1[i].bullish);
      bool shortSetup = (bias < 0 &&  g_fvgM1[i].bullish);
      if(longSetup || shortSetup)
        {
         g_fvgM1[i].armed = true;
         PrintFormat("M1: IFVG armado %s zona [%.2f - %.2f] bias=%d",
                     longSetup ? "LONG" : "SHORT",
                     g_fvgM1[i].bottom, g_fvgM1[i].top, bias);
        }
     }
  }

//+------------------------------------------------------------------+
int Model1Bias()
  {
   double swingHigh = 0.0, swingLow = 0.0;
   int k = InpM1SwingBars;

   for(int i = k + 1; i <= InpM1BiasLookback && (swingHigh == 0.0 || swingLow == 0.0); i++)
     {
      if(swingHigh == 0.0 && IsSwingHigh(InpM1BiasTF, i, k))
         swingHigh = iHigh(_Symbol, InpM1BiasTF, i);
      if(swingLow == 0.0 && IsSwingLow(InpM1BiasTF, i, k))
         swingLow = iLow(_Symbol, InpM1BiasTF, i);
     }

   double lastClose = iClose(_Symbol, InpM1BiasTF, 1);
   if(swingHigh > 0.0 && lastClose > swingHigh)
      return(1);
   if(swingLow > 0.0 && lastClose < swingLow)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
bool IsSwingHigh(const ENUM_TIMEFRAMES tf, const int idx, const int k)
  {
   double h = iHigh(_Symbol, tf, idx);
   for(int j = 1; j <= k; j++)
     {
      if(iHigh(_Symbol, tf, idx - j) >= h) return(false);
      if(iHigh(_Symbol, tf, idx + j) >= h) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
bool IsSwingLow(const ENUM_TIMEFRAMES tf, const int idx, const int k)
  {
   double l = iLow(_Symbol, tf, idx);
   for(int j = 1; j <= k; j++)
     {
      if(iLow(_Symbol, tf, idx - j) <= l) return(false);
      if(iLow(_Symbol, tf, idx + j) <= l) return(false);
     }
   return(true);
  }

//+------------------------------------------------------------------+
void UpdateModel2()
  {
   DetectNewFvg(g_fvgM2, InpM2TF, InpM2FvgMinPoints, 2);
   ExpireZones(g_fvgM2, InpM2TF, InpM2ZoneExpiryBars);

   if(RecentRangePoints(InpM2TF, InpM2RangeBars) < InpM2MinRangePoints)
     {
      g_m2SweepDir = 0;
      return;
     }

   DetectSweep();

   if(g_m2SweepDir == 0)
      return;

   int sweepShift = iBarShift(_Symbol, InpM2TF, g_m2SweepTime);
   if(sweepShift < 0 || sweepShift > InpM2SweepWindow)
     {
      g_m2SweepDir = 0;
      return;
     }

   if(!IsDisplacement(1, g_m2SweepDir))
      return;

   for(int i = 0; i < ArraySize(g_fvgM2); i++)
     {
      if(g_fvgM2[i].inverted || g_fvgM2[i].traded)
         continue;
      bool wantBearishFvg = (g_m2SweepDir > 0);
      if(g_fvgM2[i].bullish == wantBearishFvg)
         continue;
      if(!IsInverted(g_fvgM2[i], InpM2TF))
         continue;

      g_fvgM2[i].inverted = true;
      g_fvgM2[i].invTime  = iTime(_Symbol, InpM2TF, 1);
      g_fvgM2[i].armed    = true;
      PrintFormat("M2: sweep+disp+IFVG armado %s zona [%.2f - %.2f]",
                  g_m2SweepDir > 0 ? "LONG" : "SHORT",
                  g_fvgM2[i].bottom, g_fvgM2[i].top);
      g_m2SweepDir = 0;
      break;
     }
  }

//+------------------------------------------------------------------+
void DetectSweep()
  {
   int hh = iHighest(_Symbol, InpM2TF, MODE_HIGH, InpM2SweepLookback, 2);
   int ll = iLowest(_Symbol, InpM2TF, MODE_LOW,  InpM2SweepLookback, 2);
   if(hh < 0 || ll < 0)
      return;

   double prevHigh = iHigh(_Symbol, InpM2TF, hh);
   double prevLow  = iLow(_Symbol, InpM2TF, ll);
   double h1 = iHigh(_Symbol, InpM2TF, 1);
   double l1 = iLow(_Symbol, InpM2TF, 1);
   double c1 = iClose(_Symbol, InpM2TF, 1);

   if(h1 > prevHigh && c1 < prevHigh)
     {
      g_m2SweepDir  = -1;
      g_m2SweepTime = iTime(_Symbol, InpM2TF, 1);
     }
   else if(l1 < prevLow && c1 > prevLow)
     {
      g_m2SweepDir  = 1;
      g_m2SweepTime = iTime(_Symbol, InpM2TF, 1);
     }
  }

//+------------------------------------------------------------------+
bool IsDisplacement(const int idx, const int dir)
  {
   double body = MathAbs(iClose(_Symbol, InpM2TF, idx) - iOpen(_Symbol, InpM2TF, idx));
   double sum = 0.0;
   for(int i = idx + 1; i <= idx + InpM2AvgBodyBars; i++)
      sum += MathAbs(iClose(_Symbol, InpM2TF, i) - iOpen(_Symbol, InpM2TF, i));
   double avg = sum / InpM2AvgBodyBars;
   if(avg <= 0.0)
      return(false);

   bool bigBody = (body >= InpM2DispFactor * avg);
   bool rightDir = (dir > 0)
                   ? (iClose(_Symbol, InpM2TF, idx) > iOpen(_Symbol, InpM2TF, idx))
                   : (iClose(_Symbol, InpM2TF, idx) < iOpen(_Symbol, InpM2TF, idx));
   return(bigBody && rightDir);
  }

//+------------------------------------------------------------------+
double RecentRangePoints(const ENUM_TIMEFRAMES tf, const int bars)
  {
   int hh = iHighest(_Symbol, tf, MODE_HIGH, bars, 1);
   int ll = iLowest(_Symbol, tf, MODE_LOW,  bars, 1);
   if(hh < 0 || ll < 0)
      return(0.0);
   return((iHigh(_Symbol, tf, hh) - iLow(_Symbol, tf, ll)) / _Point);
  }

//+------------------------------------------------------------------+
void DetectNewFvg(SFvg &arr[], const ENUM_TIMEFRAMES tf, const int minPoints, const int model)
  {
   double low1  = iLow(_Symbol, tf, 1);
   double high1 = iHigh(_Symbol, tf, 1);
   double low3  = iLow(_Symbol, tf, 3);
   double high3 = iHigh(_Symbol, tf, 3);
   datetime t2  = iTime(_Symbol, tf, 2);
   if(t2 == 0)
      return;

   for(int i = 0; i < ArraySize(arr); i++)
      if(arr[i].time == t2)
         return;

   double minSize = minPoints * _Point;

   if(low1 - high3 >= minSize)
      AddFvg(arr, t2, low1, high3, true, model);
   else if(low3 - high1 >= minSize)
      AddFvg(arr, t2, low3, high1, false, model);
  }

//+------------------------------------------------------------------+
void AddFvg(SFvg &arr[], const datetime t, const double top, const double bottom,
            const bool bullish, const int model)
  {
   int n = ArraySize(arr);
   ArrayResize(arr, n + 1);
   arr[n].time     = t;
   arr[n].top      = top;
   arr[n].bottom   = bottom;
   arr[n].bullish  = bullish;
   arr[n].inverted = false;
   arr[n].invTime  = 0;
   arr[n].armed    = false;
   arr[n].traded   = false;
   arr[n].model    = model;
  }

//+------------------------------------------------------------------+
bool IsInverted(const SFvg &f, const ENUM_TIMEFRAMES tf)
  {
   double c1 = iClose(_Symbol, tf, 1);
   if(f.bullish)
      return(c1 < f.bottom);
   return(c1 > f.top);
  }

//+------------------------------------------------------------------+
void ExpireZones(SFvg &arr[], const ENUM_TIMEFRAMES tf, const int expiryBars)
  {
   for(int i = ArraySize(arr) - 1; i >= 0; i--)
     {
      int shift = iBarShift(_Symbol, tf, arr[i].time);
      if(shift < 0 || shift > expiryBars || arr[i].traded)
         RemoveFvg(arr, i);
     }
  }

//+------------------------------------------------------------------+
void RemoveFvg(SFvg &arr[], const int idx)
  {
   int n = ArraySize(arr);
   for(int i = idx; i < n - 1; i++)
      arr[i] = arr[i + 1];
   ArrayResize(arr, n - 1);
  }

//+------------------------------------------------------------------+
void CheckRetestEntries(SFvg &arr[], const ENUM_TIMEFRAMES tf)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < ArraySize(arr); i++)
     {
      if(!arr[i].armed || arr[i].traded || !arr[i].inverted)
         continue;

      if(iTime(_Symbol, tf, 0) <= arr[i].invTime)
         continue;

      bool isLongZone = !arr[i].bullish;

      if(isLongZone && bid <= arr[i].top && bid >= arr[i].bottom)
        {
         if(TryOpen(ORDER_TYPE_BUY, arr[i].model))
            arr[i].traded = true;
        }
      else if(!isLongZone && bid >= arr[i].bottom && bid <= arr[i].top)
        {
         if(TryOpen(ORDER_TYPE_SELL, arr[i].model))
            arr[i].traded = true;
        }
     }
  }

//+------------------------------------------------------------------+
bool TryOpen(const ENUM_ORDER_TYPE type, const int model)
  {
   if(!FiltersPass())
      return(false);

   double lot = CalcLot();
   if(lot <= 0.0)
      return(false);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp = 0.0;
   string comment = (model == 1) ? "IFVG_M1" : "IFVG_M2";

   if(type == ORDER_TYPE_BUY)
     {
      sl = ask - InpStopPoints * _Point;
      if(InpExitMode == EXIT_FIXED_RR)
         tp = ask + InpStopPoints * InpFixedRR * _Point;
      if(!CheckOpenRisk(lot))
         return(false);
      if(g_trade.Buy(lot, _Symbol, 0.0, NormalizeDouble(sl, _Digits),
                     NormalizeDouble(tp, _Digits), comment))
        {
         PrintFormat("%s BUY %.2f lots SL=%.2f", comment, lot, sl);
         return(true);
        }
     }
   else
     {
      sl = bid + InpStopPoints * _Point;
      if(InpExitMode == EXIT_FIXED_RR)
         tp = bid - InpStopPoints * InpFixedRR * _Point;
      if(!CheckOpenRisk(lot))
         return(false);
      if(g_trade.Sell(lot, _Symbol, 0.0, NormalizeDouble(sl, _Digits),
                      NormalizeDouble(tp, _Digits), comment))
        {
         PrintFormat("%s SELL %.2f lots SL=%.2f", comment, lot, sl);
         return(true);
        }
     }
   PrintFormat("Fallo al abrir: %d %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return(false);
  }

//+------------------------------------------------------------------+
bool FiltersPass()
  {
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpreadPoints)
      return(false);

   int total = 0, losing = 0;
   CountPositions(total, losing);
   if(total >= InpMaxOpenPositions)
      return(false);

   if(losing >= InpMaxOpenLosing)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
void CountPositions(int &total, int &losing)
  {
   total = 0;
   losing = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      total++;
      if(PositionGetDouble(POSITION_PROFIT) < 0.0)
         losing++;
     }
  }

//+------------------------------------------------------------------+
bool CheckOpenRisk(const double newLot)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      return(true);

   double risk = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      double sl    = PositionGetDouble(POSITION_SL);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      if(sl > 0.0)
         risk += MathAbs(price - sl) / tickSize * tickValue * vol;
     }
   risk += InpStopPoints * _Point / tickSize * tickValue * newLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(risk <= balance * InpMaxOpenRiskPct / 100.0);
  }

//+------------------------------------------------------------------+
double CalcLot()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit  = balance - g_initialBalance;
   double lot     = InpBaseLot;
   if(profit > 0.0)
      lot += InpLotStepPer1000 * MathFloor(profit / 1000.0);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = MathMin(InpMaxLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < minLot)
      lot = minLot;
   return(MathMin(lot, maxLot));
  }

//+------------------------------------------------------------------+
void ManageTrailing()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      long ptype = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY)
        {
         double profit = bid - open;
         if(profit > InpTrailStartPoints * _Point)
           {
            double newSl = bid - InpTrailDistPoints * _Point;
            if(newSl > sl + _Point)
               g_trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits),
                                      PositionGetDouble(POSITION_TP));
           }
        }
      else
        {
         double profit = open - ask;
         if(profit > InpTrailStartPoints * _Point)
           {
            double newSl = ask + InpTrailDistPoints * _Point;
            if(newSl < sl - _Point)
               g_trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits),
                                      PositionGetDouble(POSITION_TP));
           }
        }
     }
  }

//+------------------------------------------------------------------+
void UpdatePanel()
  {
   int total = 0, losing = 0;
   CountPositions(total, losing);
   Comment(StringFormat(
      "IFVG DualModel 500EUR | %s M1\n"
      "Modelo 1: bias M1 + IFVG M1 | Modelo 2: sweep M1 + disp + IFVG M1\n"
      "Posiciones: %d / %d (perdiendo: %d) | Balance: %.2f EUR",
      _Symbol, total, InpMaxOpenPositions, losing,
      AccountInfoDouble(ACCOUNT_BALANCE)));
  }
//+------------------------------------------------------------------+
