---
tags: [trading, backtest, dashboard, herramienta]
creado: 2026-07-08
---

# Backtest Lab — dashboard HTML

Dashboard autocontenido en HTML/JS que replica el motor del EA y ejecuta backtests en el navegador **en milisegundos** (43.200 velas M1 ≈ 220 ms), para iterar parámetros mucho más rápido que en MT5.

- **Online**: https://claude.ai/code/artifact/4f809dd3-76e7-41ae-90dc-1c6f799c4787
- **Local**: `tools/ifvg_backtest_lab.html` en el repo (doble clic, funciona sin internet) — copia en `_adjuntos/`

## Qué incluye

- Panel con **todos los inputs del EA** (mismos nombres y defaults)
- Presets: **Recomendado 175** / **Agresivo 125** / **Baseline 100/75**
- Carga de **CSV M1 exportado de MT5** o datos demo sintéticos
- Métricas con los nombres del baseline: trades, win rate, gross profit/loss, PnL neto, balance final, retorno, balance mínimo realizado, max drawdown realizado, lote máximo, salidas por trailing/SL
- Curva de balance con crosshair y mínimo marcado
- Export de **summary JSON** y **trades CSV**

## Flujo de trabajo

1. MT5: `Ver → Símbolos → BTCUSD → Barras` → M1 → exportar CSV.
2. Dashboard: cargar CSV → ajustar parámetros → ejecutar.
3. Iterar rápido; apuntar candidatos en [[06 - Registro de pruebas]].
4. Validar los finalistas en Strategy Tester con **ticks reales** antes de live.

> [!warning] Límites
> Aproximación por barras M1 (modo OHLC): SL antes que TP dentro de la barra, trailing al cierre de barra. Es para **explorar**, no sustituye la validación con ticks en MT5. Comprobar *Tamaño del punto* y *Valor punto/lote* con el bróker (defaults: punto=1, valor=1 $/punto/lote → 150 pts × 0.03 lotes ≈ $4.5 riesgo, coherente con los backtests).
