# IFVG DualModel EA — Variante AGRESIVA

Réplica exacta del `IFVG_DualModel_EA` (misma lógica de entrada de los dos modelos, misma gestión) con los parámetros de la **variante agresiva documentada** en los backtests de `ict_macro_bot` del 2026-06-27: `focus_sl150_trail75_50_minrange125_maxloss3`.

## Diferencias con la versión normal

| Parámetro | Normal (recomendado) | Agresiva |
|---|---|---|
| `InpM2MinRangePoints` | `175` | **`125`** |
| `InpMagic` | `20260708` | **`20260709`** |
| Comentario de órdenes | `IFVG_M1` / `IFVG_M2` | `IFVG_AGG_M1` / `IFVG_AGG_M2` |

Todo lo demás es idéntico: SL 150, trailing 75/50, lote 0.03 + escalado, máx. 3 en negativo, spread 3000, riesgo abierto 50%.

## Por qué es "más agresiva"

El rango mínimo más bajo (125 vs 175) deja pasar más setups del Modelo 2 en condiciones de menos volatilidad → **más operaciones**.

Resultado del backtest documentado (BTCUSD M1, 2026-05-13 → 2026-06-13, $400 inicial):

| Variante | Trades | Win rate | PnL | Retorno | Drawdown |
|---|---:|---:|---:|---:|---:|
| Recomendada (minrange 175) | 2519 | 70.58% | +963.60 | +240.90% | **89.92** |
| **Agresiva (minrange 125)** | 3205 | 70.67% | **+1792.99** | **+448.25%** | **342.56** |

> ⚠️ **El doble de PnL a cambio de casi 4× más drawdown.** La propia nota de backtest la clasifica como "variante agresiva, no como baseline principal". No la pongas en una cuenta live cuyo drawdown de ~342 sobre $400 no puedas asumir (es un 85% del balance inicial).

## Cómo subir la agresividad más allá (opcional, NO documentado en backtests)

Estos inputs existen en el EA pero **no hay backtest que los valide** — cámbialos bajo tu propio criterio:

- `InpBaseLot` / `InpLotStepPer1000`: más tamaño por operación o escalado más rápido.
- `InpMaxOpenLosing`: permitir más de 3 posiciones en negativo (el backtest usó 3).
- `InpM2FvgMinPoints` / `InpM1FvgMinPoints`: FVGs más pequeños = más señales.
- `InpM2DispFactor`: bajar de 1.8 = displacement menos exigente = más señales.

## Uso conjunto con la versión normal

Pueden correr a la vez en el mismo terminal o en terminales distintos: los magic numbers son diferentes (`20260708` vs `20260709`), así que no se pisan entre sí. Ojo: el filtro de riesgo abierto del 50% es **por EA**, no compartido — si corren juntas en la misma cuenta, el riesgo combinado puede superar el 50%.
