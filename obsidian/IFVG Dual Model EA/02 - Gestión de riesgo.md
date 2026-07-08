---
tags: [trading, riesgo, baseline, ict_macro_bot]
---

# Gestión de riesgo (baseline ict_macro_bot)

Tomada del baseline validado por backtest de `ict_macro_bot` (BTCUSD M1). Ver [[07 - Fuentes]].

| Regla | Valor |
|---|---|
| Balance inicial de referencia | `$400` |
| Lote base | `0.03` |
| Escalado | `+0.10` lotes por cada `$1000` de beneficio sobre balance inicial |
| Lote máximo | `5.0` |
| Stop loss fijo | `150` puntos |
| Salida | **Trailing**: start `75`, distance `50` |
| Bloqueo de entradas | con `3` o más posiciones abiertas en negativo flotante |
| Spread máximo | `3000` puntos |
| Riesgo abierto máximo | `50%` del balance |
| Rango mínimo reciente (Modelo 2) | `175` puntos |
| Operaciones/día | sin límite |
| Corte diario | desactivado |
| Killzones | opcionales, desactivadas por defecto |

> [!note] Trailing 75/50
> Viene del candidato recomendado del backtest 2026-06-27: `focus_sl150_trail75_50_minrange175_maxloss3` → 2519 trades, win rate 70.58%, PnL +963.60, drawdown 89.92. Mejoró al baseline anterior (trailing 100/75) con mucho menos drawdown.

> [!warning] Regla de salida
> El SL cierra inmediatamente; las ganancias usan trailing stop y cierran al retroceder. Sin TP fijo (existe modo alternativo `EXIT_FIXED_RR` con RR 2.5 de referencia).
