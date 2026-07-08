# IFVG DualModel EA (MetaTrader 5)

EA en MQL5 para **una cuenta MT5** que opera los dos modelos únicos de entrada IFVG:

- **Modelo 1**: bias en `M15` → estructura en `M5` → entrada en **IFVG** (retest).
- **Modelo 2**: `sweep` de liquidez → `displacement` → entrada en **IFVG** (retest), en `M1`.

Se pueden activar por separado o los dos a la vez (`InpModelMode`).

## Origen de las reglas (Notion)

| Elemento | Fuente |
|---|---|
| Definición Modelo 1 `M15→M5→IFVG` y Modelo 2 `sweep→displacement→IFVG` | Página *Delta Core · Twitter Bot* (categorías de contenido `setup`) |
| Gestión de riesgo completa | *BTC M1 Inverse Retest Long Baseline* |
| Trailing 75/50 y min range 175 (candidato recomendado) | *Backtests ict_macro_bot Modelo 2 2026-06-27* (`focus_sl150_trail75_50_minrange175_maxloss3`) |

### Gestión tomada del baseline documentado

- Lote base `0.03`, escalado `+0.10` lotes por cada `$1000` de beneficio sobre balance inicial (`$400`), lote máximo `5.0`.
- Stop loss fijo `150` puntos. Sin TP fijo: salida por **trailing** (start `75`, distance `50`).
- Bloqueo de entradas con `3` o más posiciones abiertas en negativo flotante.
- Spread máximo `3000` puntos.
- Riesgo abierto máximo `50%` del balance.
- Rango mínimo reciente `175` puntos (filtro del Modelo 2).
- Sin límite de operaciones/día y sin corte diario (como el baseline). Killzones opcionales, desactivadas por defecto.

## Huecos no documentados en las notas (parametrizados, NO inventados como fijos)

Estas reglas **no estaban especificadas numéricamente** en Notion. Las implementé con la definición ICT estándar que usas (FVG, sweep, MSS, IFVG) y las dejé como inputs configurables para que las ajustes:

1. **Modelo 1 — bias M15**: las notas solo dicen `M15→M5→IFVG`. Implementado como **MSS simple**: bias alcista si el último cierre M15 rompe el último swing high (fractal de `InpM1SwingBars`), bajista si rompe el swing low, neutro si no hay ruptura (no opera).
2. **Displacement (Modelo 2)**: sin definición numérica en las notas. Implementado como cuerpo de vela ≥ `InpM2DispFactor` (1.8) × cuerpo medio de las últimas `InpM2AvgBodyBars` (20) velas.
3. **Tamaño mínimo del FVG**: no documentado. Inputs `InpM1FvgMinPoints` / `InpM2FvgMinPoints`.
4. **Expiración de zonas IFVG**: no documentada. Inputs `InpM1ZoneExpiryBars` / `InpM2ZoneExpiryBars`.
5. **Ventana sweep→displacement**: no documentada. Input `InpM2SweepWindow` (15 barras).
6. **Horarios exactos de killzones/macros**: no documentados en las páginas encontradas. Filtro opcional con dos ventanas configurables, **desactivado por defecto**.

> Nota importante: la página *Backtests ict_macro_bot Modelo 2* describe en realidad el patrón `inverse_range15_retest_long` (patrón de rango invertido), no la secuencia sweep→displacement→IFVG. De esa página tomé **solo la gestión de riesgo y el trailing validados por backtest**, no la lógica de entrada.

## Definiciones implementadas

- **FVG** (3 velas): alcista si `low[1] > high[3]`; bajista si `high[1] < low[3]`.
- **IFVG** (inversión): un FVG alcista queda invertido cuando una vela **cierra por debajo** de su borde inferior (pasa a zona bajista); un FVG bajista queda invertido cuando una vela **cierra por encima** de su borde superior (pasa a zona alcista).
- **Entrada**: siempre por **retest** — el precio vuelve a entrar en la zona IFVG después de la vela de inversión. Una sola operación por zona.
- **Sweep**: la vela supera el máximo/mínimo de las últimas `InpM2SweepLookback` barras y **cierra de vuelta** dentro del rango.

## Instalación

1. Copia `IFVG_DualModel_EA.mq5` a `MQL5/Experts/` de tu terminal.
2. Compila en MetaEditor (F7). No requiere librerías externas (solo `Trade\Trade.mqh` estándar).
3. Arrastra el EA al gráfico de `BTCUSD` (el TF del gráfico no importa: cada modelo usa sus propios TF por `iHigh/iLow/iClose`).
4. Activa **Algo Trading**.

## Antes de pasar a live

- El baseline de Notion dice explícitamente **"Live trading: desactivado"** — los parámetros vienen de backtests, no de forward test live.
- Prueba primero en **Strategy Tester** (modo "Every tick based on real ticks") y después en **demo o en la cuenta pequeña** antes de tocar las cuentas live de los VPS.
- El escalado de lote asume balance inicial `$400` (`InpInitialBalance`) — ajústalo al balance real de la cuenta donde lo instales.
- Magic number por defecto `20260708`; usa uno distinto por cuenta/instancia si algún día corre en más de un terminal.
