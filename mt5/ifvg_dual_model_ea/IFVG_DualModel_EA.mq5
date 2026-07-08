//+------------------------------------------------------------------+
//|                                          IFVG_DualModel_EA.mq5  |
//|                                                     txatxe.code  |
//|                                                                  |
//| EA para una cuenta MetaTrader 5 con los dos modelos de entrada   |
//| IFVG documentados en las notas del proyecto:                     |
//|                                                                  |
//|   Modelo 1: bias M15 -> estructura M5 -> entrada en IFVG (M5)    |
//|   Modelo 2: sweep -> displacement -> entrada en IFVG (M1)        |
//|                                                                  |
//| Gestion de riesgo tomada del baseline documentado de             |
//| ict_macro_bot (BTCUSD M1):                                       |
//|   - SL fijo 150 puntos, salida por trailing (start 75, dist 50)  |
//|   - Lote base 0.03, +0.10 por cada $1000 de beneficio            |
//|   - Maximo 3 posiciones abiertas en negativo                     |
//|   - Spread maximo 3000, riesgo abierto maximo 50% del balance    |
//+------------------------------------------------------------------+
#property copyright "txatxe.code"
#property link      "https://github.com/txaaatxee"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- enums
enum ENUM_MODEL_MODE
  {
   MODE_MODEL1 = 0,   // Solo Modelo 1 (M15->M5->IFVG)
   MODE_MODEL2 = 1,   // Solo Modelo 2 (sweep->displacement->IFVG)
   MODE_BOTH   = 2    // Ambos modelos
  };

enum ENUM_EXIT_MODE
  {
   EXIT_TRAILING = 0, // Trailing stop (baseline)
   EXIT_FIXED_RR = 1  // TP fijo por RR
  };

//--- inputs generales
input group "=== General ==="
input long              InpMagic            = 20260708;   // Magic number
input ENUM_MODEL_MODE   InpModelMode        = MODE_BOTH;  // Modelos activos
input int               InpMaxSpreadPoints  = 3000;       // Spread maximo (puntos)
input int               InpMaxOpenPositions = 10;         // Maximo posiciones abiertas del EA

input group "=== Modelo 1 (M15 -> M5 -> IFVG) ==="
input ENUM_TIMEFRAMES   InpM1BiasTF         = PERIOD_M15; // TF de bias
input ENUM_TIMEFRAMES   InpM1EntryTF        = PERIOD_M5;  // TF de entrada
input int               InpM1SwingBars      = 3;          // Barras a cada lado del swing (fractal)
input int               InpM1BiasLookback   = 40;         // Barras M15 para buscar estructura
input int               InpM1FvgMinPoints   = 10;         // Tamano minimo del FVG (puntos)
input int               InpM1ZoneExpiryBars = 120;        // Expiracion de zona IFVG (barras M5)

input group "=== Modelo 2 (sweep -> displacement -> IFVG) ==="
input ENUM_TIMEFRAMES   InpM2TF             = PERIOD_M1;  // TF del modelo 2
input int               InpM2SweepLookback  = 30;         // Barras para detectar sweep de liquidez
input int               InpM2SweepWindow    = 15;         // Barras tras el sweep para displacement+IFVG
input double            InpM2DispFactor     = 1.8;        // Cuerpo displacement >= factor * cuerpo medio
input int               InpM2AvgBodyBars    = 20;         // Barras para cuerpo medio
input int               InpM2FvgMinPoints   = 5;          // Tamano minimo del FVG (puntos)
input int               InpM2MinRangePoints = 175;        // Rango minimo reciente (puntos, baseline 175)
input int               InpM2RangeBars      = 15;         // Barras para medir el rango
input int               InpM2ZoneExpiryBars = 90;         // Expiracion de zona IFVG (barras M1)

input group "=== Gestion (baseline ict_macro_bot) ==="
input double            InpInitialBalance   = 400.0;      // Balance inicial de referencia
input double            InpBaseLot          = 0.03;       // Lote base
input double            InpLotStepPer1000   = 0.10;       // Lotes extra por cada $1000 de beneficio
input double            InpMaxLot           = 5.0;        // Lote maximo
input int               InpStopPoints       = 150;        // Stop loss fijo (puntos)
input int               InpMaxOpenLosing    = 3;          // Bloqueo: max posiciones abiertas en negativo
input double            InpMaxOpenRiskPct   = 50.0;       // Riesgo abierto maximo (% balance)

input group "=== Salida ==="
input ENUM_EXIT_MODE    InpExitMode         = EXIT_TRAILING; // Modo de salida
input int               InpTrailStartPoints = 75;         // Trailing start (puntos)
input int               InpTrailDistPoints  = 50;         // Trailing distance (puntos)
input double            InpFixedRR          = 2.5;        // RR si salida por TP fijo

input group "=== Killzones (opcional, desactivado en baseline) ==="
input bool              InpUseKillzones     = false;      // Filtrar por ventanas horarias
input string            InpKZ1Start         = "08:00";    // Killzone 1 inicio (hora servidor)
input string            InpKZ1End           = "11:00";    // Killzone 1 fin
input string            InpKZ2Start         = "13:30";    // Killzone 2 inicio
input string            InpKZ2End           = "16:00";    // Killzone 2 fin

//--- estructura de FVG / IFVG
struct SFvg
  {
   datetime          time;        // hora de la barra central del FVG
   double            top;         // borde superior del gap
   double            bottom;      // borde inferior del gap
   bool              bullish;     // FVG alcista (gap hacia arriba)
   bool              inverted;    // se ha invertido (IFVG)
   datetime          invTime;     // hora de la inversion
   bool              armed;       // zona valida esperando retest
   bool              traded;      // ya se opero esta zona
   int               model;       // 1 o 2
  };

//--- estado global
CTrade   g_trade;
SFvg     g_fvgM1[];         // FVGs del modelo 1 (TF entrada M5)
SFvg     g_fvgM2[];         // FVGs del modelo 2 (TF M1)
datetime g_lastBarM1Entry = 0;
datetime g_lastBarM2      = 0;

// estado del sweep del modelo 2: +1 sweep de minimos (esperar largo),
// -1 sweep de maximos (esperar corto), 0 sin sweep activo
int      g_m2SweepDir  = 0;
datetime g_m2SweepTime = 0;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);

   ArrayResize(g_fvgM1, 0);
   ArrayResize(g_fvgM2, 0);

   Print("IFVG_DualModel_EA iniciado. Modo=", EnumToString(InpModelMode),
         " Simbolo=", _Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }

//+------------------------------------------------------------------+
//| Tick principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
  {
   // gestion de posiciones abiertas en cada tick
   if(InpExitMode == EXIT_TRAILING)
      ManageTrailing();

   // deteccion por barra nueva en cada TF de modelo
   if(InpModelMode == MODE_MODEL1 || InpModelMode == MODE_BOTH)
     {
      if(IsNewBar(InpM1EntryTF, g_lastBarM1Entry))
         UpdateModel1();
     }
   if(InpModelMode == MODE_MODEL2 || InpModelMode == MODE_BOTH)
     {
      if(IsNewBar(InpM2TF, g_lastBarM2))
         UpdateModel2();
     }

   // entradas por retest en cada tick
   CheckRetestEntries(g_fvgM1, InpM1EntryTF);
   CheckRetestEntries(g_fvgM2, InpM2TF);

   UpdatePanel();
  }

//+------------------------------------------------------------------+
//| Barra nueva                                                      |
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
//| Modelo 1: bias M15 por MSS + IFVG en M5                          |
//+------------------------------------------------------------------+
void UpdateModel1()
  {
   DetectNewFvg(g_fvgM1, InpM1EntryTF, InpM1FvgMinPoints, 1);
   ExpireZones(g_fvgM1, InpM1EntryTF, InpM1ZoneExpiryBars);

   int bias = Model1Bias();
   if(bias == 0)
      return;

   // buscar inversiones en M5 alineadas con el bias:
   //  bias alcista -> FVG bajista invertido = zona de soporte -> largo
   //  bias bajista -> FVG alcista invertido = zona de resistencia -> corto
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
         PrintFormat("Modelo 1: IFVG armado %s zona [%.2f - %.2f] bias=%d",
                     longSetup ? "LONG" : "SHORT",
                     g_fvgM1[i].bottom, g_fvgM1[i].top, bias);
        }
     }
  }

//+------------------------------------------------------------------+
//| Bias del modelo 1: MSS simple en el TF de bias                   |
//| +1 si el ultimo cierre rompe el ultimo swing high                |
//| -1 si rompe el ultimo swing low, 0 si no hay ruptura             |
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
//| Modelo 2: sweep -> displacement -> IFVG en M1                    |
//+------------------------------------------------------------------+
void UpdateModel2()
  {
   DetectNewFvg(g_fvgM2, InpM2TF, InpM2FvgMinPoints, 2);
   ExpireZones(g_fvgM2, InpM2TF, InpM2ZoneExpiryBars);

   // filtro de rango minimo (baseline: min range 175 puntos)
   if(RecentRangePoints(InpM2TF, InpM2RangeBars) < InpM2MinRangePoints)
     {
      g_m2SweepDir = 0;
      return;
     }

   DetectSweep();

   if(g_m2SweepDir == 0)
      return;

   // caducidad de la ventana del sweep
   int sweepShift = iBarShift(_Symbol, InpM2TF, g_m2SweepTime);
   if(sweepShift < 0 || sweepShift > InpM2SweepWindow)
     {
      g_m2SweepDir = 0;
      return;
     }

   // displacement en la ultima barra cerrada, en direccion del sweep esperado
   if(!IsDisplacement(1, g_m2SweepDir))
      return;

   // buscar FVG contrario que la barra de displacement invierte
   //  g_m2SweepDir=+1 (largo tras sweep de minimos) -> FVG bajista invertido
   //  g_m2SweepDir=-1 (corto tras sweep de maximos) -> FVG alcista invertido
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
      PrintFormat("Modelo 2: sweep(%d) + displacement + IFVG armado %s zona [%.2f - %.2f]",
                  g_m2SweepDir, g_m2SweepDir > 0 ? "LONG" : "SHORT",
                  g_fvgM2[i].bottom, g_fvgM2[i].top);
      g_m2SweepDir = 0; // consumir el sweep
      break;
     }
  }

//+------------------------------------------------------------------+
//| Sweep de liquidez en la ultima barra cerrada                     |
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

   // barrido de maximos que cierra de vuelta por debajo -> buscar corto
   if(h1 > prevHigh && c1 < prevHigh)
     {
      g_m2SweepDir  = -1;
      g_m2SweepTime = iTime(_Symbol, InpM2TF, 1);
     }
   // barrido de minimos que cierra de vuelta por encima -> buscar largo
   else if(l1 < prevLow && c1 > prevLow)
     {
      g_m2SweepDir  = 1;
      g_m2SweepTime = iTime(_Symbol, InpM2TF, 1);
     }
  }

//+------------------------------------------------------------------+
//| Displacement: cuerpo grande en la direccion dir                  |
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
//| Rango reciente en puntos                                         |
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
//| Deteccion de FVG de 3 velas en la barra recien cerrada           |
//| FVG alcista: low[1] > high[3]  (gap entre vela 3 y vela 1)       |
//| FVG bajista: high[1] < low[3]                                    |
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

   // evitar duplicados
   for(int i = 0; i < ArraySize(arr); i++)
      if(arr[i].time == t2)
         return;

   double minSize = minPoints * _Point;

   if(low1 - high3 >= minSize)         // FVG alcista
      AddFvg(arr, t2, low1, high3, true, model);
   else if(low3 - high1 >= minSize)    // FVG bajista
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
//| Inversion del FVG: cierre completo al otro lado del gap          |
//| FVG alcista invertido: cierre por debajo del bottom              |
//| FVG bajista invertido: cierre por encima del top                 |
//+------------------------------------------------------------------+
bool IsInverted(const SFvg &f, const ENUM_TIMEFRAMES tf)
  {
   double c1 = iClose(_Symbol, tf, 1);
   if(f.bullish)
      return(c1 < f.bottom);
   return(c1 > f.top);
  }

//+------------------------------------------------------------------+
//| Expirar zonas viejas                                             |
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
//| Entradas por retest de zonas armadas                             |
//+------------------------------------------------------------------+
void CheckRetestEntries(SFvg &arr[], const ENUM_TIMEFRAMES tf)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = 0; i < ArraySize(arr); i++)
     {
      if(!arr[i].armed || arr[i].traded || !arr[i].inverted)
         continue;

      // no operar en la misma barra de la inversion: exigir retest posterior
      if(iTime(_Symbol, tf, 0) <= arr[i].invTime)
         continue;

      // FVG bajista invertido -> zona alcista -> largo cuando el precio vuelve a la zona
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
//| Apertura con todos los filtros de gestion                        |
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
   PrintFormat("Fallo al abrir orden: %d %s", g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
   return(false);
  }

//+------------------------------------------------------------------+
//| Filtros previos a la entrada                                     |
//+------------------------------------------------------------------+
bool FiltersPass()
  {
   // spread
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > InpMaxSpreadPoints)
      return(false);

   // killzones
   if(InpUseKillzones && !InKillzone())
      return(false);

   // maximo de posiciones del EA
   int total = 0, losing = 0;
   CountPositions(total, losing);
   if(total >= InpMaxOpenPositions)
      return(false);

   // bloqueo por posiciones en negativo (baseline: 3)
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
//| Riesgo abierto: suma de perdidas potenciales a SL <= X% balance  |
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
   // riesgo de la nueva posicion
   risk += InpStopPoints * _Point / tickSize * tickValue * newLot;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(risk <= balance * InpMaxOpenRiskPct / 100.0);
  }

//+------------------------------------------------------------------+
//| Lote: base + escalado por beneficio (baseline)                   |
//+------------------------------------------------------------------+
double CalcLot()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double profit  = balance - InpInitialBalance;
   double lot     = InpBaseLot;
   if(profit > 0.0)
      lot += InpLotStepPer1000 * MathFloor(profit / 1000.0);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = MathMin(InpMaxLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep > 0.0)
      lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   return(lot);
  }

//+------------------------------------------------------------------+
//| Trailing stop (baseline: start 75, dist 50; SL fijo si negativo) |
//+------------------------------------------------------------------+
void ManageTrailing()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
        {
         double profitPts = (bid - open) / _Point;
         if(profitPts >= InpTrailStartPoints)
           {
            double newSl = NormalizeDouble(bid - InpTrailDistPoints * _Point, _Digits);
            if(newSl > sl + _Point)
               g_trade.PositionModify(ticket, newSl, tp);
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double profitPts = (open - ask) / _Point;
         if(profitPts >= InpTrailStartPoints)
           {
            double newSl = NormalizeDouble(ask + InpTrailDistPoints * _Point, _Digits);
            if(sl == 0.0 || newSl < sl - _Point)
               g_trade.PositionModify(ticket, newSl, tp);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Killzones                                                        |
//+------------------------------------------------------------------+
bool InKillzone()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int nowMin = dt.hour * 60 + dt.min;
   return(InWindow(nowMin, InpKZ1Start, InpKZ1End) ||
          InWindow(nowMin, InpKZ2Start, InpKZ2End));
  }

//+------------------------------------------------------------------+
bool InWindow(const int nowMin, const string startStr, const string endStr)
  {
   int s = ParseHHMM(startStr);
   int e = ParseHHMM(endStr);
   if(s < 0 || e < 0)
      return(false);
   if(s <= e)
      return(nowMin >= s && nowMin < e);
   return(nowMin >= s || nowMin < e); // ventana que cruza medianoche
  }

//+------------------------------------------------------------------+
int ParseHHMM(const string str)
  {
   string parts[];
   if(StringSplit(str, StringGetCharacter(":", 0), parts) != 2)
      return(-1);
   return((int)StringToInteger(parts[0]) * 60 + (int)StringToInteger(parts[1]));
  }

//+------------------------------------------------------------------+
//| Panel de estado                                                  |
//+------------------------------------------------------------------+
void UpdatePanel()
  {
   int total = 0, losing = 0;
   CountPositions(total, losing);

   int armed1 = 0, armed2 = 0;
   for(int i = 0; i < ArraySize(g_fvgM1); i++)
      if(g_fvgM1[i].armed && !g_fvgM1[i].traded) armed1++;
   for(int i = 0; i < ArraySize(g_fvgM2); i++)
      if(g_fvgM2[i].armed && !g_fvgM2[i].traded) armed2++;

   string txt = StringFormat(
      "IFVG DualModel EA | Modo: %s\n"
      "Posiciones: %d (negativas: %d / max %d)\n"
      "Zonas armadas M1: %d | M2: %d | Sweep M2: %d\n"
      "Lote actual: %.2f | Balance: %.2f",
      EnumToString(InpModelMode), total, losing, InpMaxOpenLosing,
      armed1, armed2, g_m2SweepDir, CalcLot(),
      AccountInfoDouble(ACCOUNT_BALANCE));
   Comment(txt);
  }
//+------------------------------------------------------------------+
