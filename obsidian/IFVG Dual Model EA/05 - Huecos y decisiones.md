---
tags: [trading, decisiones, documentacion]
---

# Huecos y decisiones de diseño

Reglas que **no estaban especificadas numéricamente** en las notas de Notion. Se implementaron con la definición ICT estándar y quedaron como inputs configurables (no como valores fijos inventados).

| # | Hueco | Decisión implementada |
|---|---|---|
| 1 | Bias M15 del Modelo 1 (las notas solo dicen `M15→M5→IFVG`) | MSS simple: cierre M15 rompe último swing high/low (fractal 3 barras) |
| 2 | Definición numérica de *displacement* | Cuerpo ≥ `1.8×` cuerpo medio de las últimas `20` velas |
| 3 | Tamaño mínimo del FVG | Inputs: `10` pts (M1/M5) y `5` pts (M2/M1) |
| 4 | Expiración de zonas IFVG | Inputs: `120` barras M5 / `90` barras M1 |
| 5 | Ventana sweep → displacement | Input: `15` barras |
| 6 | Horarios exactos de killzones/macros | Filtro opcional con 2 ventanas, **desactivado por defecto** (baseline sin corte diario) |

> [!important] Sobre la página "Backtests ict_macro_bot Modelo 2"
> Esa página describe en realidad el patrón `inverse_range15_retest_long` (rango invertido), **no** la secuencia sweep→displacement→IFVG. De ella se tomó **solo la gestión de riesgo y el trailing validados por backtest**, no la lógica de entrada.

## Detalles de implementación

- Entrada siempre por retest, nunca en la misma vela de la inversión.
- Una sola operación por zona IFVG (`traded` flag).
- El sweep del Modelo 2 se consume al armar una zona (no genera múltiples setups).
- Riesgo abierto: suma de pérdidas potenciales a SL de todas las posiciones del EA + la nueva ≤ 50% del balance.
- El escalado de lote usa `balance − InpInitialBalance` (beneficio realizado), redondeado al lot step del símbolo.
