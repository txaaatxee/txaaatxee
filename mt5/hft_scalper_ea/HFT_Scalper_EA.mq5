//+------------------------------------------------------------------+
//|                                              HFT_Scalper_EA.mq5  |
//|                                                     txatxe.code  |
//|                                                                  |
//| SCALPER DE ALTA FRECUENCIA PARA XAUUSD Y BTCUSD.                 |
//|                                                                  |
//| Diseño multi-símbolo: TODAS las distancias (SL, TP, trailing,    |
//| breakeven, spread máximo) se calculan como múltiplos del ATR     |
//| del propio símbolo. No hay puntos fijos, así que el mismo EA     |
//| funciona en XAUUSD (3 dígitos) y BTCUSD (2 dígitos) sin tocar    |
//| nada. Se arrastra a un gráfico M1 de cada símbolo, con un        |
//| Magic number DISTINTO por gráfico.                               |
//|                                                                  |
//| Estrategia (scalping de momentum en M1):                        |
//|   - Tendencia micro: EMA rápida vs EMA lenta                     |
//|   - Disparo: vela de momentum (cuerpo >= factor x cuerpo medio)  |
//|     cerrando en dirección de la tendencia                        |
//|   - Gestión en cada tick: breakeven + trailing por ATR           |
//|                                                                  |
//| Calibrado para cuentas de ~500 EUR: riesgo 0.5% = 2.50 EUR por   |
//| operación, alcanzable con lote mínimo 0.01 en XAUUSD y BTCUSD.   |
//| El lote se recalcula sobre el balance REAL en cada entrada, así  |
//| que crece/decrece solo con la cuenta.                            |
//|                                                                  |
//| Protecciones:                                                    |
//|   - Riesgo % por operación (lote calculado, no fijo)             |
//|   - Corte diario de pérdidas (% del balance al inicio del día)   |
//|   - Máximo de operaciones por día y posiciones simultáneas       |
//|   - Filtro de spread adaptativo (fracción del ATR)               |
//|   - Cooldown de barras entre entradas                            |
//+------------------------------------------------------------------+
#property copyright "txatxe.code"
#property link      "https://github.com/txaaatxee"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- enums
enum ENUM_EXIT_STYLE
  {
   EXIT_TRAIL_ATR = 0,  // Breakeven + trailing por ATR
   EXIT_FIXED_TP  = 1   // TP fijo por múltiplo de ATR
  };

//--- inputs
input group "=== General ==="
input long            InpMagic            = 20260710;      // Magic number (¡distinto por gráfico!)
input int             InpMaxOpenPositions = 1;             // Máx. posiciones simultáneas de este EA
input int             InpCooldownBars     = 3;             // Barras M1 mínimas entre entradas
input double          InpMaxSpreadAtrFrac = 0.15;          // Spread máx. como fracción del ATR

input group "=== Señal (momentum M1) ==="
input ENUM_TIMEFRAMES InpTF               = PERIOD_M1;     // Timeframe de trabajo
input int             InpEmaFast          = 5;             // EMA rápida
input int             InpEmaSlow          = 20;            // EMA lenta
input int             InpAtrPeriod        = 14;            // Periodo ATR
input double          InpMomentumFactor   = 1.5;           // Cuerpo >= factor x cuerpo medio
input int             InpAvgBodyBars      = 20;            // Barras para el cuerpo medio

input group "=== Riesgo ==="
input double          InpRiskPct          = 0.5;           // Riesgo por operación (% balance)
input double          InpMaxLot           = 1.0;           // Lote máximo absoluto
input double          InpDailyLossPct     = 3.0;           // Corte diario de pérdidas (% balance)
input int             InpMaxTradesPerDay  = 30;            // Máx. operaciones por día

input group "=== Salida ==="
input ENUM_EXIT_STYLE InpExitStyle        = EXIT_TRAIL_ATR; // Estilo de salida
input double          InpSlAtrMult        = 1.2;           // SL = múltiplo de ATR
input double          InpTpAtrMult        = 1.8;           // TP = múltiplo de ATR (si TP fijo)
input double          InpBeAtrMult        = 0.6;           // Breakeven al ganar este múltiplo de ATR
input double          InpTrailAtrMult     = 0.8;           // Distancia de trailing en ATR

input group "=== Sesión (opcional) ==="
input bool            InpUseSession       = false;         // Filtrar por horario
input string          InpSessionStart     = "07:00";       // Inicio (hora servidor)
input string          InpSessionEnd       = "21:00";       // Fin (hora servidor)

//--- estado global
CTrade   g_trade;
int      g_hEmaFast = INVALID_HANDLE;
int      g_hEmaSlow = INVALID_HANDLE;
int      g_hAtr     = INVALID_HANDLE;
datetime g_lastBar        = 0;
datetime g_lastEntryBar   = 0;
int      g_tradesToday    = 0;
int      g_dayOfYear      = -1;
double   g_dayStartBalance = 0.0;
bool     g_dailyLocked    = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_trade.SetExpertMagicNumber(InpMagic);
   g_trade.SetDeviationInPoints(50);

   g_hEmaFast = iMA(_Symbol, InpTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
   g_hEmaSlow = iMA(_Symbol, InpTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
   g_hAtr     = iATR(_Symbol, InpTF, InpAtrPeriod);
   if(g_hEmaFast == INVALID_HANDLE || g_hEmaSlow == INVALID_HANDLE || g_hAtr == INVALID_HANDLE)
     {
      Print("Error creando indicadores");
      return(INIT_FAILED);
     }

   ResetDay();
   PrintFormat("HFT_Scalper_EA iniciado. Simbolo=%s Magic=%I64d Riesgo=%.2f%%"
               " CorteDiario=%.1f%%", _Symbol, InpMagic, InpRiskPct, InpDailyLossPct);
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
   CheckNewDay();

   // gestión de posiciones abiertas en cada tick
   if(InpExitStyle == EXIT_TRAIL_ATR)
      ManageExits();

   UpdatePanel();

   if(g_dailyLocked)
      return;

   // señales solo en barra nueva
   if(!IsNewBar())
      return;

   TrySignal();
  }

//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, InpTF, 0);
   if(t == 0 || t == g_lastBar)
      return(false);
   g_lastBar = t;
   return(true);
  }

//+------------------------------------------------------------------+
//| Reinicio diario: contador de trades y corte de pérdidas          |
//+------------------------------------------------------------------+
void CheckNewDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_year != g_dayOfYear)
      ResetDay();

   // corte diario de pérdidas: equity vs balance de inicio del día
   if(!g_dailyLocked && g_dayStartBalance > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= g_dayStartBalance * (1.0 - InpDailyLossPct / 100.0))
        {
         g_dailyLocked = true;
         PrintFormat("CORTE DIARIO: equity %.2f <= limite. No se abren mas"
                     " operaciones hoy.", equity);
        }
     }
  }

//+------------------------------------------------------------------+
void ResetDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_dayOfYear       = dt.day_of_year;
   g_tradesToday     = 0;
   g_dailyLocked     = false;
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
  }

//+------------------------------------------------------------------+
//| Señal de momentum en la última barra cerrada                     |
//+------------------------------------------------------------------+
void TrySignal()
  {
   if(!FiltersPass())
      return;

   double emaF[2], emaS[2];
   if(CopyBuffer(g_hEmaFast, 0, 1, 2, emaF) < 2) return;
   if(CopyBuffer(g_hEmaSlow, 0, 1, 2, emaS) < 2) return;

   double o1 = iOpen(_Symbol, InpTF, 1);
   double c1 = iClose(_Symbol, InpTF, 1);
   double body = MathAbs(c1 - o1);

   // cuerpo medio de referencia
   double sum = 0.0;
   for(int i = 2; i <= InpAvgBodyBars + 1; i++)
      sum += MathAbs(iClose(_Symbol, InpTF, i) - iOpen(_Symbol, InpTF, i));
   double avgBody = sum / InpAvgBodyBars;
   if(avgBody <= 0.0 || body < InpMomentumFactor * avgBody)
      return;

   bool upTrend   = (emaF[0] > emaS[0]);
   bool downTrend = (emaF[0] < emaS[0]);
   bool bullBar   = (c1 > o1);
   bool bearBar   = (c1 < o1);

   // largo: tendencia alcista + vela de momentum alcista cerrando sobre la EMA rápida
   if(upTrend && bullBar && c1 > emaF[0])
      TryOpen(ORDER_TYPE_BUY);
   // corto: tendencia bajista + vela de momentum bajista cerrando bajo la EMA rápida
   else if(downTrend && bearBar && c1 < emaF[0])
      TryOpen(ORDER_TYPE_SELL);
  }

//+------------------------------------------------------------------+
bool FiltersPass()
  {
   if(g_tradesToday >= InpMaxTradesPerDay)
      return(false);

   if(CountPositions() >= InpMaxOpenPositions)
      return(false);

   // cooldown entre entradas
   if(g_lastEntryBar > 0)
     {
      int barsSince = iBarShift(_Symbol, InpTF, g_lastEntryBar);
      if(barsSince >= 0 && barsSince < InpCooldownBars)
         return(false);
     }

   // spread adaptativo: fracción del ATR
   double atr = GetAtr();
   if(atr <= 0.0)
      return(false);
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(spread > InpMaxSpreadAtrFrac * atr)
      return(false);

   if(InpUseSession && !InSession())
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
double GetAtr()
  {
   double buf[1];
   if(CopyBuffer(g_hAtr, 0, 1, 1, buf) < 1)
      return(0.0);
   return(buf[0]);
  }

//+------------------------------------------------------------------+
int CountPositions()
  {
   int total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      total++;
     }
   return(total);
  }

//+------------------------------------------------------------------+
//| Lote por riesgo %: riesgo monetario / pérdida a SL por lote      |
//+------------------------------------------------------------------+
double CalcLot(const double slDistance)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || slDistance <= 0.0)
      return(0.0);

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * InpRiskPct / 100.0;
   double lossPerLot = slDistance / tickSize * tickValue;
   double lot = riskMoney / lossPerLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = MathMin(InpMaxLot, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX));
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;
   if(lot < minLot)
     {
      // el riesgo calculado no llega al lote mínimo: usar mínimo y avisar
      double realRiskPct = lossPerLot * minLot / balance * 100.0;
      PrintFormat("AVISO: lote por riesgo < minimo. Usando %.2f (riesgo real"
                  " ~%.2f%% del balance)", minLot, realRiskPct);
      lot = minLot;
     }
   return(MathMin(lot, maxLot));
  }

//+------------------------------------------------------------------+
void TryOpen(const ENUM_ORDER_TYPE type)
  {
   double atr = GetAtr();
   if(atr <= 0.0)
      return;

   double slDist = InpSlAtrMult * atr;
   double lot = CalcLot(slDist);
   if(lot <= 0.0)
      return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl, tp = 0.0;

   if(type == ORDER_TYPE_BUY)
     {
      sl = ask - slDist;
      if(InpExitStyle == EXIT_FIXED_TP)
         tp = ask + InpTpAtrMult * atr;
      if(g_trade.Buy(lot, _Symbol, 0.0, NormalizeDouble(sl, _Digits),
                     NormalizeDouble(tp, _Digits), "HFT_SCALP"))
        {
         g_tradesToday++;
         g_lastEntryBar = iTime(_Symbol, InpTF, 0);
         PrintFormat("SCALP BUY %.2f lots SL=%.2f ATR=%.2f", lot, sl, atr);
         return;
        }
     }
   else
     {
      sl = bid + slDist;
      if(InpExitStyle == EXIT_FIXED_TP)
         tp = bid - InpTpAtrMult * atr;
      if(g_trade.Sell(lot, _Symbol, 0.0, NormalizeDouble(sl, _Digits),
                      NormalizeDouble(tp, _Digits), "HFT_SCALP"))
        {
         g_tradesToday++;
         g_lastEntryBar = iTime(_Symbol, InpTF, 0);
         PrintFormat("SCALP SELL %.2f lots SL=%.2f ATR=%.2f", lot, sl, atr);
         return;
        }
     }
   PrintFormat("Fallo al abrir orden: %d %s", g_trade.ResultRetcode(),
               g_trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
//| Breakeven + trailing por ATR en cada tick                        |
//+------------------------------------------------------------------+
void ManageExits()
  {
   double atr = GetAtr();
   if(atr <= 0.0)
      return;

   double beDist    = InpBeAtrMult * atr;
   double trailDist = InpTrailAtrMult * atr;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;

      long   ptype = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY)
        {
         double profit = bid - open;
         if(profit < beDist)
            continue;
         // breakeven asegurado y trailing por detrás del precio
         double newSl = MathMax(open, bid - trailDist);
         if(newSl > sl + _Point)
            g_trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits),
                                   PositionGetDouble(POSITION_TP));
        }
      else
        {
         double profit = open - ask;
         if(profit < beDist)
            continue;
         double newSl = MathMin(open, ask + trailDist);
         if(sl == 0.0 || newSl < sl - _Point)
            g_trade.PositionModify(ticket, NormalizeDouble(newSl, _Digits),
                                   PositionGetDouble(POSITION_TP));
        }
     }
  }

//+------------------------------------------------------------------+
bool InSession()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   string today = StringFormat("%04d.%02d.%02d ", dt.year, dt.mon, dt.day);
   datetime s = StringToTime(today + InpSessionStart);
   datetime e = StringToTime(today + InpSessionEnd);
   return(now >= s && now <= e);
  }

//+------------------------------------------------------------------+
void UpdatePanel()
  {
   double atr = GetAtr();
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) -
                   SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Comment(StringFormat(
      "HFT Scalper | %s M1\n"
      "ATR: %.2f  Spread: %.2f (max %.2f)\n"
      "Trades hoy: %d / %d  Posiciones: %d / %d\n"
      "Equity: %.2f  Inicio dia: %.2f  %s",
      _Symbol, atr, spread, InpMaxSpreadAtrFrac * atr,
      g_tradesToday, InpMaxTradesPerDay,
      CountPositions(), InpMaxOpenPositions,
      AccountInfoDouble(ACCOUNT_EQUITY), g_dayStartBalance,
      g_dailyLocked ? ">>> BLOQUEADO POR CORTE DIARIO <<<" : ""));
  }
//+------------------------------------------------------------------+
