---
tags: [trading, testing, registro]
---

# Registro de pruebas

| Fecha | Entorno | Resultado | Notas |
|---|---|---|---|
| 2026-07-08 | Prueba del usuario | ✅ OK | "Está probado y va bien" — confirmado tras la entrega del EA |

## Plantilla para nuevas pruebas

```
| YYYY-MM-DD | Strategy Tester / Demo / Live VPS 1 / Live VPS 2 | ✅/❌ | símbolo, periodo, trades, win rate, PnL, drawdown, incidencias |
```

## Referencia de backtests del baseline (ict_macro_bot, BTCUSD M1, 2026-05-13 → 2026-06-13)

| Variante | Trades | Win rate | PnL | Drawdown |
|---|---:|---:|---:|---:|
| baseline_sl150_trail100_75_maxloss3 | 3236 | 63.54% | +843.72 | 227.28 |
| **focus_sl150_trail75_50_minrange175_maxloss3** (recomendado) | 2519 | 70.58% | +963.60 | **89.92** |
| focus_sl150_trail75_50_minrange125_maxloss3 (agresivo) | 3205 | 70.67% | +1792.99 | 342.56 |

Pendiente: forward test en demo y luego en las cuentas live de los VPS — apuntar aquí cada resultado.
