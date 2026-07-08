---
tags: [trading, mt5, ea, agresivo]
creado: 2026-07-08
---

# Variante agresiva

Réplica del EA con los parámetros de la variante agresiva documentada en los backtests: `focus_sl150_trail75_50_minrange125_maxloss3`.

- Archivo: `mt5/ifvg_dual_model_ea_aggressive/IFVG_DualModel_EA_Aggressive.mq5`
- Magic number: `20260709` (puede convivir con la normal en la misma cuenta)
- Único cambio de lógica efectiva: **min range 125** (vs 175) → más setups del Modelo 2

## Backtest documentado (BTCUSD M1, 1 mes, $400)

| | Recomendada | Agresiva |
|---|---:|---:|
| Trades | 2519 | 3205 |
| Win rate | 70.58% | 70.67% |
| PnL | +963.60 | **+1792.99** |
| Retorno | +240.90% | **+448.25%** |
| Drawdown | 89.92 | **342.56** |

> [!danger] Riesgo
> Casi el doble de PnL pero ~4× más drawdown (342 sobre $400 = 85% del balance inicial). La nota de backtest la clasifica como "variante agresiva, no baseline principal". Solo para cuenta que pueda asumir ese drawdown, y probar antes en demo.

Relación: [[01 - Modelos de entrada]] · [[02 - Gestión de riesgo]] · [[06 - Registro de pruebas]]
