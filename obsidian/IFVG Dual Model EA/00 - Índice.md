---
tags: [trading, mt5, ifvg, ea, proyecto]
proyecto: IFVG Dual Model EA
estado: probado-ok
creado: 2026-07-08
---

# IFVG Dual Model EA — Índice

EA en MQL5 para MetaTrader 5 que opera los **dos modelos únicos de entrada IFVG** en una cuenta, con la gestión de riesgo del baseline validado de `ict_macro_bot`.

> [!success] Estado
> **Probado y funcionando** (confirmado 2026-07-08).

## Notas del proyecto

- [[01 - Modelos de entrada]] — reglas del Modelo 1 y Modelo 2
- [[02 - Gestión de riesgo]] — baseline completo (SL, trailing, lotes, bloqueos)
- [[03 - Parámetros del EA]] — todos los inputs y sus valores por defecto
- [[04 - Instalación y uso]] — compilar, instalar, checklist antes de live
- [[05 - Huecos y decisiones]] — qué no estaba documentado y cómo se resolvió
- [[06 - Registro de pruebas]] — log de tests y resultados
- [[07 - Fuentes]] — páginas de Notion y ubicación del código
- [[08 - Variante agresiva]] — réplica con min range 125 (más trades, más drawdown)
- [[09 - Backtest Lab (dashboard HTML)]] — backtests en navegador en milisegundos
- [[10 - Despliegue en Axi]] — conversión de puntos ×100, presets y checklist live
- [[11 - HFT Scalper (XAUUSD + BTCUSD)]] — scalper M1 auto-adaptativo por ATR (proyecto aparte)

## Código

- Repo: `txaaatxee/txaaatxee` · rama `claude/mt5-dual-live-accounts-l50vq6`
- Archivo: `mt5/ifvg_dual_model_ea/IFVG_DualModel_EA.mq5`
- Magic number por defecto: `20260708`
