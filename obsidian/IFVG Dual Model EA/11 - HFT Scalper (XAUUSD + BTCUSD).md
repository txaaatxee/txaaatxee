---
tags: [trading, mt5, scalping, xauusd, btcusd, axi]
creado: 2026-07-09
estado: sin-validar
---

# HFT Scalper — XAUUSD + BTCUSD (Axi live)

EA de scalping de alta frecuencia en M1. **No comparte lógica con los modelos IFVG**: es un proyecto aparte dentro del mismo repo.

> [!warning] Sin validar
> Creado 2026-07-09. **Ningún backtest con datos reales todavía.** Los datos demo del lab (paseo aleatorio) queman la cuenta — eso es lo esperado con datos sintéticos, no dice nada del modelo. Backtest con CSV real de Axi antes de arrancar en live.

## Diseño

- **Multi-símbolo por ATR**: todas las distancias (SL, TP, breakeven, trailing, spread máx.) son múltiplos del ATR(14) del propio símbolo. El mismo EA funciona en XAUUSD (3 dígitos) y BTCUSD (2 dígitos) **sin conversión de puntos** — se acabó el problema de los ×100.
- **Señal** (barra M1 cerrada): EMA 5 > EMA 20 (o <) + vela de momentum (cuerpo ≥ 1.5× cuerpo medio de 20 barras) cerrando en dirección y al otro lado de la EMA rápida.
- **Entrada**: a mercado al abrir la barra siguiente.
- **Salida**: breakeven a 0.6×ATR + trailing a 0.8×ATR (o TP fijo 1.8×ATR).

## Protecciones

| Protección | Default |
|---|---|
| Riesgo por operación | 0.5% del balance (lote calculado) |
| Corte diario de pérdidas | 3% → no abre más ese día |
| Máx. trades/día | 30 |
| Posiciones simultáneas | 1 |
| Cooldown entre entradas | 3 barras M1 |
| Spread máximo | 0.15 × ATR (adaptativo) |

> [!note] Cuenta de 16€
> Con el lote mínimo 0.01 el riesgo real por trade queda MUY por encima del 0.5% (el EA avisa en el log con el % real). En BTCUSD un SL de 1.2×ATR puede ser ~2€ por trade = ~12% del balance. Es lo que hay con una cuenta tan pequeña.

## Uso en Axi

1. Compilar `mt5/hft_scalper_ea/HFT_Scalper_EA.mq5` (F7).
2. Arrastrar a un gráfico **M1** de XAUUSD y a otro de BTCUSD.
3. **Magic distinto en cada gráfico** (p. ej. 20260710 y 20260711).
4. Sin presets: los defaults se auto-adaptan por ATR.

## Backtest rápido

`tools/hft_scalper_lab.html` — mismo motor en el navegador:
- CSV M1 exportado de MT5 (mismo formato que el IFVG lab)
- Presets XAUUSD/BTCUSD Axi (contrato 100/1, spread 0.30/20)
- 43k velas en ~15 ms; exporta trades a CSV
- Simulación conservadora: SL tiene prioridad sobre TP en la misma barra

## Código

- EA: `mt5/hft_scalper_ea/HFT_Scalper_EA.mq5`
- Lab: `tools/hft_scalper_lab.html`
- Rama: `claude/mt5-dual-live-accounts-l50vq6`
